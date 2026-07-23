import '../models/location.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';
import 'osrm_service.dart';
import 'traffic_service.dart';
import 'weather_service.dart';

enum AdvisorySeverity { info, warning, critical }

class AdvisoryMessage {
  final AdvisorySeverity severity;
  final String message;
  const AdvisoryMessage({required this.severity, required this.message});
}

class RouteStop {
  final FoodOrder order;
  final double distanceFromPreviousKm;
  final DateTime estimatedArrival;
  final bool isAtRiskOfLateness;
  final String reasonNote;

  /// Whether this stop's distance/time came from a real OSRM road route
  /// (true) or the straight-line Haversine fallback (false) — shown in
  /// the UI so the vendor knows how much to trust a given ETA.
  final bool usedRealRoadData;

  const RouteStop({
    required this.order,
    required this.distanceFromPreviousKm,
    required this.estimatedArrival,
    required this.isAtRiskOfLateness,
    required this.reasonNote,
    this.usedRealRoadData = false,
  });
}

class TimeWindowGroup {
  final DateTime windowStart;
  final List<RouteStop> stops;
  const TimeWindowGroup({required this.windowStart, required this.stops});

  double get groupDistanceKm =>
      stops.fold(0.0, (sum, s) => sum + s.distanceFromPreviousKm);
}

/// Everything here comes from a sensor, a clock, or a routing engine —
/// nothing the vendor has to type in. Weather from the weather API,
/// traffic from the traffic API (when configured), real road distances
/// from OSRM, time-of-day from the device clock.
class RouteConditions {
  final WeatherCondition weather;
  final double trafficMultiplier;
  final DateTime computedAt;

  const RouteConditions({
    required this.weather,
    required this.trafficMultiplier,
    required this.computedAt,
  });

  bool get hasSlowdown =>
      weather.penaltyMinutesPerStop > 0 || trafficMultiplier > 1.05;
}

class RoutePlan {
  final List<TimeWindowGroup> windows;
  final RouteConditions conditions;
  final List<AdvisoryMessage> advisories;
  final int suggestedDelayMinutes;
  final int routeHealthScore;

  const RoutePlan({
    required this.windows,
    required this.conditions,
    this.advisories = const [],
    this.suggestedDelayMinutes = 0,
    this.routeHealthScore = 100,
  });

  String get routeHealthLabel {
    if (routeHealthScore >= 85) return 'Great day for deliveries';
    if (routeHealthScore >= 60) return 'Manageable — some care needed';
    return 'Tough conditions — plan carefully';
  }

  double get totalDistanceKm =>
      windows.fold(0.0, (sum, w) => sum + w.groupDistanceKm);
  int get totalStops => windows.fold(0, (sum, w) => sum + w.stops.length);
  List<RouteStop> get flatStops => windows.expand((w) => w.stops).toList();
  List<RouteStop> get atRiskStops =>
      flatStops.where((s) => s.isAtRiskOfLateness).toList();

  /// How many stops actually got real road distances vs the straight-line
  /// fallback — a quick honesty check on how much of this plan to trust.
  int get stopsWithRealRoadData =>
      flatStops.where((s) => s.usedRealRoadData).length;
}

/// Builds the vendor's delivery plan out of pending orders — fully
/// automatic, no vendor input anywhere in this pipeline.
///
/// 1. GROUP BY TIME — orders needed around the same time batch together.
/// 2. SEQUENCE BY REAL ROAD COST — for each time-window, one OSRM Table
///    call fetches a full pairwise matrix of real road distances/
///    durations between every stop in that batch (not a straight line —
///    actual streets and footpaths). Nearest-neighbour then 2-opt local
///    search run against that real-cost matrix, fixing greedy nearest-
///    neighbour's known weakness of painting itself into a bad corner.
///    If OSRM's free public server is unreachable for a given window
///    (it's a best-effort demo service, not a guaranteed SLA), that
///    window quietly falls back to straight-line distance instead of
///    breaking route planning — every stop's `usedRealRoadData` flag
///    says honestly which case applied.
/// 3. WEATHER + TRAFFIC REFINE TIMING, NOT ORDER — both fetched
///    automatically; a citywide slowdown affects every stop equally, so
///    it changes ETA accuracy, not which route is shortest.
/// 4. ADVISORIES turn all of the above into plain "what should I actually
///    do" answers — storms, night delivery, an overloaded batch, orders
///    at risk of lateness — computed automatically, never asked of the
///    vendor.
/// 5. CHEAPEST INSERTION lets a new order that arrives mid-route slot
///    into the *existing* plan instantly, using straight-line distance
///    (no new network calls, by design — a full "refresh" reconciles it
///    with real road data afterward).
class RouteOptimizerService {
  final WeatherService _weatherService;
  final TrafficService _trafficService;
  final OsrmService _osrmService;

  RouteOptimizerService({
    WeatherService? weatherService,
    TrafficService? trafficService,
    OsrmService? osrmService,
  }) : _weatherService = weatherService ?? WeatherService(),
       _trafficService = trafficService ?? TrafficService(),
       _osrmService = osrmService ?? OsrmService();

  Future<RoutePlan> buildDeliveryPlan(
    List<FoodOrder> pendingOrders, {
    Location vendorStart = CampusLocations.vendorBase,
    Duration windowSize = AppConfig.deliveryWindowSize,
  }) async {
    final now = DateTime.now();
    final isNightNow = now.hour >= 19 || now.hour < 6;

    final weather = await _weatherService.getCurrentConditions(vendorStart);
    final trafficMultiplier = await _trafficService.getTrafficMultiplier(
      origin: vendorStart,
      destinations: pendingOrders.map((o) => o.deliveryLocation).toList(),
    );

    final conditions = RouteConditions(
      weather: weather,
      trafficMultiplier: trafficMultiplier,
      computedAt: now,
    );

    if (pendingOrders.isEmpty) {
      return RoutePlan(windows: const [], conditions: conditions);
    }

    final groupedByWindow = _groupByTimeWindow(pendingOrders, windowSize);
    final windowStarts = groupedByWindow.keys.toList()..sort();

    final windows = <TimeWindowGroup>[];
    Location currentPosition = vendorStart;
    DateTime currentTime = now;

    for (final windowStart in windowStarts) {
      final ordersInWindow = groupedByWindow[windowStart]!;

      // One network call per batch — a real distance/duration matrix
      // between the vendor's current position and every stop in this
      // window, in one shot. Falls back to null (handled gracefully
      // everywhere below) if OSRM's free demo server can't answer.
      final windowLocations = [
        currentPosition,
        ...ordersInWindow.map((o) => o.deliveryLocation),
      ];
      final matrix = await _osrmService.getDistanceMatrix(windowLocations);

      double costMinutes(Location from, Location to) {
        final real = matrix?.durationMinutes(from, to);
        if (real != null) return real;
        return (from.distanceToKm(to) / AppConfig.assumedSpeedKmh) * 60;
      }

      var sequenced = _nearestNeighbourRoute(
        ordersInWindow,
        currentPosition,
        costMinutes,
      );
      sequenced = _twoOptImprove(sequenced, currentPosition, costMinutes);

      final stops = <RouteStop>[];
      for (var i = 0; i < sequenced.length; i++) {
        final order = sequenced[i];
        final realDistanceKm = matrix?.distanceKm(
          currentPosition,
          order.deliveryLocation,
        );
        final distanceKm =
            realDistanceKm ??
            currentPosition.distanceToKm(order.deliveryLocation);
        final usedReal = realDistanceKm != null;

        final baseTravelMinutes = costMinutes(
          currentPosition,
          order.deliveryLocation,
        );
        final totalMinutes =
            baseTravelMinutes * trafficMultiplier +
            weather.penaltyMinutesPerStop;
        final arrival = currentTime.add(
          Duration(minutes: totalMinutes.round()),
        );
        final lateBy = arrival.difference(order.preferredTime).inMinutes;
        final atRisk = lateBy > AppConfig.latenessGraceMinutes;

        stops.add(
          RouteStop(
            order: order,
            distanceFromPreviousKm: distanceKm,
            estimatedArrival: arrival,
            isAtRiskOfLateness: atRisk,
            usedRealRoadData: usedReal,
            reasonNote: i == 0
                ? (usedReal
                      ? 'Closest stop by real road distance from your starting point'
                      : 'Closest stop to your starting point (estimated)')
                : (usedReal
                      ? 'Next closest stop by real road distance'
                      : 'Next closest stop after the previous delivery (estimated)'),
          ),
        );

        currentPosition = order.deliveryLocation;
        currentTime = arrival;
      }
      windows.add(TimeWindowGroup(windowStart: windowStart, stops: stops));
    }

    final allStops = windows.expand((w) => w.stops).toList();
    final atRiskCount = allStops.where((s) => s.isAtRiskOfLateness).length;
    final largestWindowSize = windows.isEmpty
        ? 0
        : windows.map((w) => w.stops.length).reduce((a, b) => a > b ? a : b);
    final advisories = _generateAdvisories(
      weather: weather,
      totalStops: allStops.length,
      atRiskCount: atRiskCount,
      isNightNow: isNightNow,
      largestWindowSize: largestWindowSize,
    );
    final suggestedDelay = _suggestedDelayMinutes(
      weather,
      atRiskCount,
      allStops.length,
    );
    final healthScore = _computeHealthScore(
      weather: weather,
      atRiskCount: atRiskCount,
      totalStops: allStops.length,
    );

    return RoutePlan(
      windows: windows,
      conditions: conditions,
      advisories: advisories,
      suggestedDelayMinutes: suggestedDelay,
      routeHealthScore: healthScore,
    );
  }

  int _computeHealthScore({
    required WeatherCondition weather,
    required int atRiskCount,
    required int totalStops,
  }) {
    var score = 100;
    if (weather.isStorming) {
      score -= 40;
    } else if (weather.isRaining) {
      score -= 15;
    }
    if (totalStops > 0) {
      final atRiskRatio = atRiskCount / totalStops;
      score -= (atRiskRatio * 40).round();
    }
    return score.clamp(0, 100);
  }

  List<AdvisoryMessage> _generateAdvisories({
    required WeatherCondition weather,
    required int totalStops,
    required int atRiskCount,
    required bool isNightNow,
    required int largestWindowSize,
  }) {
    final advisories = <AdvisoryMessage>[];

    if (weather.isStorming) {
      advisories.add(
        const AdvisoryMessage(
          severity: AdvisorySeverity.critical,
          message:
              'Thunderstorm right now. If it\'s not safe to walk, consider '
              'holding this batch 15-20 minutes and messaging customers — a '
              'short delay beats risking a fall or ruined food in a storm.',
        ),
      );
    } else if (weather.isRaining) {
      advisories.add(
        const AdvisoryMessage(
          severity: AdvisorySeverity.warning,
          message:
              'It\'s raining. Cover the food before heading out, and the '
              'ETAs below already assume you\'ll be moving slower than usual.',
        ),
      );
    }

    if (isNightNow) {
      advisories.add(
        const AdvisoryMessage(
          severity: AdvisorySeverity.warning,
          message:
              'It\'s after dark. Stick to well-lit paths between '
              'buildings, and consider going with someone else if you\'re '
              'carrying cash.',
        ),
      );
    }

    if (largestWindowSize > 5) {
      advisories.add(
        AdvisoryMessage(
          severity: AdvisorySeverity.warning,
          message:
              'One batch has $largestWindowSize stops — that\'s a lot to '
              'carry hot food through in one trip. Consider splitting it into '
              'two shorter runs so the later stops don\'t get cold food.',
        ),
      );
    }

    if (totalStops > 0 && atRiskCount == totalStops) {
      advisories.add(
        const AdvisoryMessage(
          severity: AdvisorySeverity.critical,
          message:
              'Every stop on this run is likely to be late under current '
              'conditions. Worth messaging all of today\'s customers now '
              'rather than rushing and risking an accident.',
        ),
      );
    } else if (atRiskCount > 0) {
      advisories.add(
        AdvisoryMessage(
          severity: AdvisorySeverity.warning,
          message:
              '$atRiskCount of $totalStops stop(s) are likely to run late. '
              'Consider giving those customers a heads-up now.',
        ),
      );
    }

    if (advisories.isEmpty) {
      advisories.add(
        const AdvisoryMessage(
          severity: AdvisorySeverity.info,
          message: 'Conditions look clear — this route should run on schedule.',
        ),
      );
    }
    return advisories;
  }

  int _suggestedDelayMinutes(
    WeatherCondition weather,
    int atRiskCount,
    int totalStops,
  ) {
    if (weather.isStorming) return 20;
    if (atRiskCount == totalStops && totalStops > 0 && weather.isRaining)
      return 15;
    return 0;
  }

  /// Slots a new order into an *already-built* plan — a fresh order
  /// arrives while she's already out delivering. Deliberately stays on
  /// straight-line distance rather than fetching a new OSRM matrix, so
  /// this stays instant with zero network calls; the next full "refresh"
  /// reconciles it against real road data along with everything else.
  RoutePlan insertOrderIntoPlan(
    RoutePlan currentPlan,
    FoodOrder newOrder, {
    required Location vendorStart,
    Duration windowSize = AppConfig.deliveryWindowSize,
  }) {
    final conditions = currentPlan.conditions;

    double costMinutes(Location from, Location to) {
      return (from.distanceToKm(to) / AppConfig.assumedSpeedKmh) * 60;
    }

    final t = newOrder.preferredTime;
    final windowMinutes = windowSize.inMinutes;
    final bucketMinute = (t.minute ~/ windowMinutes) * windowMinutes;
    final newOrderWindowStart = DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      bucketMinute,
    );

    final windows = List<TimeWindowGroup>.from(currentPlan.windows);
    final matchIndex = windows.indexWhere(
      (w) => w.windowStart == newOrderWindowStart,
    );

    if (matchIndex == -1) {
      final distanceKm = vendorStart.distanceToKm(newOrder.deliveryLocation);
      final travelMinutes =
          costMinutes(vendorStart, newOrder.deliveryLocation) *
          conditions.trafficMultiplier;
      final arrival = newOrderWindowStart.add(
        Duration(minutes: travelMinutes.round()),
      );

      final newWindow = TimeWindowGroup(
        windowStart: newOrderWindowStart,
        stops: [
          RouteStop(
            order: newOrder,
            distanceFromPreviousKm: distanceKm,
            estimatedArrival: arrival,
            isAtRiskOfLateness:
                arrival.difference(newOrder.preferredTime).inMinutes >
                AppConfig.latenessGraceMinutes,
            reasonNote:
                'New order — added to a fresh batch for this time (estimated)',
          ),
        ],
      );

      final insertAt = windows.indexWhere(
        (w) => w.windowStart.isAfter(newOrderWindowStart),
      );
      if (insertAt == -1) {
        windows.add(newWindow);
      } else {
        windows.insert(insertAt, newWindow);
      }

      return RoutePlan(
        windows: windows,
        conditions: conditions,
        advisories: currentPlan.advisories,
        suggestedDelayMinutes: currentPlan.suggestedDelayMinutes,
        routeHealthScore: currentPlan.routeHealthScore,
      );
    }

    final window = windows[matchIndex];
    final anchorPosition = matchIndex == 0
        ? vendorStart
        : windows[matchIndex - 1].stops.last.order.deliveryLocation;

    final existingLocations = [
      anchorPosition,
      ...window.stops.map((s) => s.order.deliveryLocation),
    ];

    var bestIndex = existingLocations.length - 1;
    var bestExtraCost = double.infinity;

    for (var i = 0; i < existingLocations.length; i++) {
      final before = existingLocations[i];
      final afterExists = i < existingLocations.length - 1;
      final after = afterExists ? existingLocations[i + 1] : null;

      final costWithout = afterExists ? costMinutes(before, after!) : 0.0;
      final costBeforeNew = costMinutes(before, newOrder.deliveryLocation);
      final costNewAfter = afterExists
          ? costMinutes(newOrder.deliveryLocation, after!)
          : 0.0;

      final extraCost = costBeforeNew + costNewAfter - costWithout;
      if (extraCost < bestExtraCost) {
        bestExtraCost = extraCost;
        bestIndex = i;
      }
    }

    final newOrderSequence = List<FoodOrder>.from(
      window.stops.map((s) => s.order),
    )..insert(bestIndex, newOrder);

    final rebuiltStops = <RouteStop>[];
    Location current = anchorPosition;
    DateTime currentTime = matchIndex == 0
        ? conditions.computedAt
        : windows[matchIndex - 1].stops.last.estimatedArrival;

    for (var i = 0; i < newOrderSequence.length; i++) {
      final order = newOrderSequence[i];
      final distanceKm = current.distanceToKm(order.deliveryLocation);
      final travelMinutes =
          costMinutes(current, order.deliveryLocation) *
          conditions.trafficMultiplier;
      final totalMinutes =
          travelMinutes + conditions.weather.penaltyMinutesPerStop;
      final arrival = currentTime.add(Duration(minutes: totalMinutes.round()));

      rebuiltStops.add(
        RouteStop(
          order: order,
          distanceFromPreviousKm: distanceKm,
          estimatedArrival: arrival,
          isAtRiskOfLateness:
              arrival.difference(order.preferredTime).inMinutes >
              AppConfig.latenessGraceMinutes,
          reasonNote: order.id == newOrder.id
              ? 'New order — slotted in at the cheapest point in this batch (estimated)'
              : rebuiltStops.isEmpty
              ? 'Closest stop to your starting point (estimated)'
              : 'Next closest stop after the previous delivery (estimated)',
        ),
      );

      current = order.deliveryLocation;
      currentTime = arrival;
    }

    windows[matchIndex] = TimeWindowGroup(
      windowStart: window.windowStart,
      stops: rebuiltStops,
    );

    return RoutePlan(
      windows: windows,
      conditions: conditions,
      advisories: currentPlan.advisories,
      suggestedDelayMinutes: currentPlan.suggestedDelayMinutes,
      routeHealthScore: currentPlan.routeHealthScore,
    );
  }

  Map<DateTime, List<FoodOrder>> _groupByTimeWindow(
    List<FoodOrder> orders,
    Duration windowSize,
  ) {
    final map = <DateTime, List<FoodOrder>>{};
    final windowMinutes = windowSize.inMinutes;
    for (final order in orders) {
      final t = order.preferredTime;
      final bucketMinute = (t.minute ~/ windowMinutes) * windowMinutes;
      final windowStart = DateTime(
        t.year,
        t.month,
        t.day,
        t.hour,
        bucketMinute,
      );
      map.putIfAbsent(windowStart, () => []).add(order);
    }
    return map;
  }

  List<FoodOrder> _nearestNeighbourRoute(
    List<FoodOrder> orders,
    Location startPosition,
    double Function(Location, Location) costMinutes,
  ) {
    final remaining = List<FoodOrder>.from(orders);
    final route = <FoodOrder>[];
    Location current = startPosition;
    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => costMinutes(
          current,
          a.deliveryLocation,
        ).compareTo(costMinutes(current, b.deliveryLocation)),
      );
      final next = remaining.removeAt(0);
      route.add(next);
      current = next.deliveryLocation;
    }
    return route;
  }

  List<FoodOrder> _twoOptImprove(
    List<FoodOrder> route,
    Location startPosition,
    double Function(Location, Location) costMinutes,
  ) {
    if (route.length < 3) return route;

    double totalCost(List<FoodOrder> r) {
      var cost = 0.0;
      var current = startPosition;
      for (final order in r) {
        cost += costMinutes(current, order.deliveryLocation);
        current = order.deliveryLocation;
      }
      return cost;
    }

    var best = List<FoodOrder>.from(route);
    var bestCost = totalCost(best);
    var improved = true;

    while (improved) {
      improved = false;
      for (var i = 0; i < best.length - 1; i++) {
        for (var j = i + 1; j < best.length; j++) {
          final candidate = List<FoodOrder>.from(best);
          final segment = candidate.sublist(i, j + 1).reversed.toList();
          candidate.replaceRange(i, j + 1, segment);
          final candidateCost = totalCost(candidate);
          if (candidateCost < bestCost - 0.001) {
            best = candidate;
            bestCost = candidateCost;
            improved = true;
          }
        }
      }
    }
    return best;
  }
}
