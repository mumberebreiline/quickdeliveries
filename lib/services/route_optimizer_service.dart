import '../models/location.dart';
import '../models/order.dart';
import '../models/route_hazard.dart';
import '../utils/constants.dart';
import 'hazard_service.dart';
import 'traffic_service.dart';
import 'weather_service.dart';

/// How urgent a piece of advice is — drives both sort order and color
/// when shown to the vendor.
enum AdvisorySeverity { info, warning, critical }

/// One concrete, actionable recommendation — not a raw number, an actual
/// answer to "what should I do about this."
class AdvisoryMessage {
  final AdvisorySeverity severity;
  final String message;

  const AdvisoryMessage({required this.severity, required this.message});
}

/// One stop on the vendor's planned route.
class RouteStop {
  final FoodOrder order;
  final double distanceFromPreviousKm;
  final DateTime estimatedArrival;
  final bool isAtRiskOfLateness;
  final double hazardPenaltyMinutes;

  /// A short, plain-language reason this stop landed where it did —
  /// this is the actual "guidance" the vendor asked for, not just a
  /// number she has to interpret herself.
  final String reasonNote;

  const RouteStop({
    required this.order,
    required this.distanceFromPreviousKm,
    required this.estimatedArrival,
    required this.isAtRiskOfLateness,
    required this.hazardPenaltyMinutes,
    required this.reasonNote,
  });
}

/// A batch of orders sharing a delivery time-window, in visiting order.
class TimeWindowGroup {
  final DateTime windowStart;
  final List<RouteStop> stops;

  const TimeWindowGroup({required this.windowStart, required this.stops});

  double get groupDistanceKm =>
      stops.fold(0.0, (sum, s) => sum + s.distanceFromPreviousKm);
}

/// A snapshot of the real-world conditions the plan was built under —
/// shown to the vendor so she understands *why* the route looks the way
/// it does, not just what it is.
class RouteConditions {
  final WeatherCondition weather;
  final double trafficMultiplier;
  final List<RouteHazard> activeHazards;
  final DateTime computedAt;

  const RouteConditions({
    required this.weather,
    required this.trafficMultiplier,
    required this.activeHazards,
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

  /// A single 0-100 number summarizing how favorable today's conditions
  /// are for delivering — the "at a glance, is today rough or easy" read,
  /// for when she doesn't have time to read every advisory line.
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
}

/// Builds the vendor's delivery plan out of pending orders.
///
/// Three layers of intelligence, in order of how much they actually change
/// the plan:
///
/// 1. GROUP BY TIME. Same as before — orders needed around the same time
///    get batched into one run instead of separate trips.
///
/// 2. SEQUENCE BY COST, NOT JUST DISTANCE. Each candidate stop's cost is
///    its travel time *plus* any hazard penalty reported for that
///    location (a flooded path, a gate that's closed right now, etc.).
///    An initial route is built greedily (nearest-neighbour), then
///    improved with **2-opt**: repeatedly test reversing a segment of the
///    route, keep the reversal if it lowers total cost, until nothing
///    helps. This is the standard fix for nearest-neighbour's known
///    weakness — it can back itself into a locally-bad path — and it's
///    the part of this system that's a genuine algorithm, not an API call.
///
/// 3. WEATHER + TRAFFIC REFINE THE TIMING, NOT THE ORDER. A citywide rain
///    delay or general traffic slowdown affects every stop equally, so it
///    doesn't change which order is shortest — but it changes how
///    accurate the ETA and lateness warnings are, which matters just as
///    much for helping the vendor decide what to do.
class RouteOptimizerService {
  final HazardService _hazardService;
  final WeatherService _weatherService;
  final TrafficService _trafficService;

  RouteOptimizerService({
    HazardService? hazardService,
    WeatherService? weatherService,
    TrafficService? trafficService,
  }) : _hazardService = hazardService ?? HazardService(),
       _weatherService = weatherService ?? WeatherService(),
       _trafficService = trafficService ?? TrafficService();

  Future<RoutePlan> buildDeliveryPlan(
    List<FoodOrder> pendingOrders, {
    Location vendorStart = CampusLocations.vendorBase,
    Duration windowSize = AppConfig.deliveryWindowSize,
  }) async {
    final now = DateTime.now();
    final isNightNow = now.hour >= 19 || now.hour < 6;

    // Gather real-world conditions once per plan build — not once per
    // stop or per pair, which would mean dozens of API calls for a
    // handful of orders.
    List<RouteHazard> hazards;
    try {
      hazards = await _hazardService.getActiveHazards();
    } catch (_) {
      hazards = const [];
    }
    final weather = await _weatherService.getCurrentConditions(vendorStart);
    final trafficMultiplier = await _trafficService.getTrafficMultiplier(
      origin: vendorStart,
      destinations: pendingOrders.map((o) => o.deliveryLocation).toList(),
    );

    final conditions = RouteConditions(
      weather: weather,
      trafficMultiplier: trafficMultiplier,
      activeHazards: hazards,
      computedAt: now,
    );

    if (pendingOrders.isEmpty) {
      return RoutePlan(windows: const [], conditions: conditions);
    }

    double hazardPenaltyFor(Location location) {
      double total = 0;
      for (final hazard in hazards) {
        if (hazard.isNear(location)) {
          total += hazard.penaltyMinutes(
            isRainingNow: weather.isRaining || weather.isStorming,
            isNightNow: isNightNow,
          );
        }
      }
      return total;
    }

    String reasonFor({required bool isFirst, required double hazardPenalty}) {
      if (hazardPenalty > 0) {
        return isFirst
            ? 'Closest stop, but has a flagged hazard nearby — extra time added'
            : 'Next closest available stop, with a flagged hazard nearby';
      }
      return isFirst
          ? 'Closest stop to your starting point'
          : 'Next closest stop after the previous delivery';
    }

    final groupedByWindow = _groupByTimeWindow(pendingOrders, windowSize);
    final windowStarts = groupedByWindow.keys.toList()..sort();

    final windows = <TimeWindowGroup>[];
    Location currentPosition = vendorStart;
    DateTime currentTime = now;

    for (final windowStart in windowStarts) {
      final ordersInWindow = groupedByWindow[windowStart]!;

      var sequenced = _nearestNeighbourRoute(
        ordersInWindow,
        currentPosition,
        hazardPenaltyFor,
      );
      sequenced = _twoOptImprove(sequenced, currentPosition, hazardPenaltyFor);

      final stops = <RouteStop>[];
      for (var i = 0; i < sequenced.length; i++) {
        final order = sequenced[i];
        final distanceKm = currentPosition.distanceToKm(order.deliveryLocation);
        final hazardPenalty = hazardPenaltyFor(order.deliveryLocation);

        final travelMinutes =
            (distanceKm / AppConfig.assumedSpeedKmh) * 60 * trafficMultiplier;
        final totalMinutes =
            travelMinutes + hazardPenalty + weather.penaltyMinutesPerStop;

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
            hazardPenaltyMinutes: hazardPenalty,
            reasonNote: reasonFor(
              isFirst: i == 0,
              hazardPenalty: hazardPenalty,
            ),
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
      trafficMultiplier: trafficMultiplier,
      hazards: hazards,
      totalStops: allStops.length,
      atRiskCount: atRiskCount,
      isNightNow: isNightNow,
      largestWindowSize: largestWindowSize,
    );
    final suggestedDelay = _suggestedDelayMinutes(
      weather,
      hazards,
      atRiskCount,
      allStops.length,
    );
    final healthScore = _computeHealthScore(
      weather: weather,
      hazardCount: hazards.length,
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

  /// A single 0-100 read on how favorable conditions are right now —
  /// starts at a perfect 100 and loses points for each real factor working
  /// against her. Not a black box: every deduction below maps directly to
  /// something already visible in the advisories, just condensed into one
  /// number for a glance.
  int _computeHealthScore({
    required WeatherCondition weather,
    required int hazardCount,
    required int atRiskCount,
    required int totalStops,
  }) {
    var score = 100;

    if (weather.isStorming) {
      score -= 40;
    } else if (weather.isRaining) {
      score -= 15;
    }

    score -= hazardCount * 5;

    if (totalStops > 0) {
      final atRiskRatio = atRiskCount / totalStops;
      score -= (atRiskRatio * 40).round();
    }

    return score.clamp(0, 100);
  }

  /// Turns raw conditions into plain answers to "what should I actually do
  /// right now" — this is the part that matters more than the numbers.
  List<AdvisoryMessage> _generateAdvisories({
    required WeatherCondition weather,
    required double trafficMultiplier,
    required List<RouteHazard> hazards,
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

    if (hazards.isNotEmpty) {
      final names = hazards.map((h) => h.description).take(2).join('; ');
      advisories.add(
        AdvisoryMessage(
          severity: AdvisorySeverity.warning,
          message:
              '${hazards.length} flagged hazard(s) near this route ($names'
              '${hazards.length > 2 ? ', and more' : ''}) — extra time is '
              'already built into the affected stops below.',
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

  /// A rough, honest suggestion for how long to hold the batch, when
  /// conditions call for it — 0 means "no reason to wait."
  int _suggestedDelayMinutes(
    WeatherCondition weather,
    List<RouteHazard> hazards,
    int atRiskCount,
    int totalStops,
  ) {
    if (weather.isStorming) return 20;
    if (atRiskCount == totalStops && totalStops > 0 && weather.isRaining)
      return 15;
    return 0;
  }

  /// Slots a single new order into an *already-built* plan without
  /// re-fetching weather/traffic/hazards or re-running a full 2-opt pass —
  /// this is the fast path for "a new order just came in while she's
  /// already out delivering." It reuses the conditions from [currentPlan]
  /// and finds the cheapest position to insert [newOrder] into whichever
  /// time-window it belongs to (adding a new window if none fits).
  ///
  /// This is intentionally a lighter-weight approximation, not a full
  /// re-optimization — only the affected window's stops get fresh ETAs;
  /// everything else is left as-is until the vendor next taps "refresh,"
  /// which reruns the complete pipeline (fresh conditions + full 2-opt).
  /// That trade-off is the point: instant feedback now, full accuracy on
  /// the next deliberate refresh — not two different sources of truth.
  RoutePlan insertOrderIntoPlan(
    RoutePlan currentPlan,
    FoodOrder newOrder, {
    required Location vendorStart,
    Duration windowSize = AppConfig.deliveryWindowSize,
  }) {
    final conditions = currentPlan.conditions;
    final isNightNow =
        conditions.computedAt.hour >= 19 || conditions.computedAt.hour < 6;

    double hazardPenaltyFor(Location location) {
      double total = 0;
      for (final hazard in conditions.activeHazards) {
        if (hazard.isNear(location)) {
          total += hazard.penaltyMinutes(
            isRainingNow:
                conditions.weather.isRaining || conditions.weather.isStorming,
            isNightNow: isNightNow,
          );
        }
      }
      return total;
    }

    // Which time-window bucket does the new order belong in?
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
      // No existing window fits — add a new one-stop window in
      // chronological order. Its ETA is a straightforward estimate;
      // it'll be refined on the next full refresh.
      final distanceKm = vendorStart.distanceToKm(newOrder.deliveryLocation);
      final hazardPenalty = hazardPenaltyFor(newOrder.deliveryLocation);
      final travelMinutes =
          (distanceKm / AppConfig.assumedSpeedKmh) *
          60 *
          conditions.trafficMultiplier;
      final arrival = newOrderWindowStart.add(
        Duration(minutes: (travelMinutes + hazardPenalty).round()),
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
            hazardPenaltyMinutes: hazardPenalty,
            reasonNote: 'New order — added to a fresh batch for this time',
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

    // Existing window — find the cheapest position to insert the new
    // stop, exactly the "cheapest insertion" approach: try every gap
    // between consecutive stops (plus the very start and end), keep
    // whichever adds the least extra cost.
    final window = windows[matchIndex];
    final anchorPosition = matchIndex == 0
        ? vendorStart
        : windows[matchIndex - 1].stops.last.order.deliveryLocation;

    final existingLocations = [
      anchorPosition,
      ...window.stops.map((s) => s.order.deliveryLocation),
    ];

    var bestIndex = existingLocations.length - 1; // default: append at the end
    var bestExtraCost = double.infinity;

    for (var i = 0; i < existingLocations.length; i++) {
      final before = existingLocations[i];
      final afterExists = i < existingLocations.length - 1;
      final after = afterExists ? existingLocations[i + 1] : null;

      final costWithout = afterExists
          ? _stopCost(before, after!, hazardPenaltyFor)
          : 0.0;
      final costBeforeNew = _stopCost(
        before,
        newOrder.deliveryLocation,
        hazardPenaltyFor,
      );
      final costNewAfter = afterExists
          ? _stopCost(newOrder.deliveryLocation, after!, hazardPenaltyFor)
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

    // Rebuild ETAs for this window only, starting from the same anchor.
    final rebuiltStops = <RouteStop>[];
    Location current = anchorPosition;
    DateTime currentTime = matchIndex == 0
        ? conditions.computedAt
        : windows[matchIndex - 1].stops.last.estimatedArrival;

    for (var i = 0; i < newOrderSequence.length; i++) {
      final order = newOrderSequence[i];
      final distanceKm = current.distanceToKm(order.deliveryLocation);
      final hazardPenalty = hazardPenaltyFor(order.deliveryLocation);
      final travelMinutes =
          (distanceKm / AppConfig.assumedSpeedKmh) *
          60 *
          conditions.trafficMultiplier;
      final totalMinutes =
          travelMinutes +
          hazardPenalty +
          conditions.weather.penaltyMinutesPerStop;
      final arrival = currentTime.add(Duration(minutes: totalMinutes.round()));

      rebuiltStops.add(
        RouteStop(
          order: order,
          distanceFromPreviousKm: distanceKm,
          estimatedArrival: arrival,
          isAtRiskOfLateness:
              arrival.difference(order.preferredTime).inMinutes >
              AppConfig.latenessGraceMinutes,
          hazardPenaltyMinutes: hazardPenalty,
          reasonNote: order.id == newOrder.id
              ? 'New order — slotted in at the cheapest point in this batch'
              : rebuiltStops.isEmpty
              ? 'Closest stop to your starting point'
              : 'Next closest stop after the previous delivery',
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

  /// cost of visiting [to] right after [from] — travel time plus whatever
  /// hazard penalty applies at the destination. This is the single
  /// function both the initial greedy pass and 2-opt optimize against.
  double _stopCost(
    Location from,
    Location to,
    double Function(Location) hazardPenaltyFor,
  ) {
    final travelMinutes =
        (from.distanceToKm(to) / AppConfig.assumedSpeedKmh) * 60;
    return travelMinutes + hazardPenaltyFor(to);
  }

  List<FoodOrder> _nearestNeighbourRoute(
    List<FoodOrder> orders,
    Location startPosition,
    double Function(Location) hazardPenaltyFor,
  ) {
    final remaining = List<FoodOrder>.from(orders);
    final route = <FoodOrder>[];
    Location current = startPosition;

    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => _stopCost(
          current,
          a.deliveryLocation,
          hazardPenaltyFor,
        ).compareTo(_stopCost(current, b.deliveryLocation, hazardPenaltyFor)),
      );
      final next = remaining.removeAt(0);
      route.add(next);
      current = next.deliveryLocation;
    }

    return route;
  }

  /// Standard 2-opt local search: repeatedly try reversing a segment of
  /// the route; keep the reversal if it lowers total cost. Stops when a
  /// full pass finds no improving swap. This is what fixes the cases
  /// where greedy nearest-neighbour paints itself into a bad corner.
  List<FoodOrder> _twoOptImprove(
    List<FoodOrder> route,
    Location startPosition,
    double Function(Location) hazardPenaltyFor,
  ) {
    if (route.length < 3) return route;

    double totalCost(List<FoodOrder> r) {
      var cost = 0.0;
      var current = startPosition;
      for (final order in r) {
        cost += _stopCost(current, order.deliveryLocation, hazardPenaltyFor);
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
