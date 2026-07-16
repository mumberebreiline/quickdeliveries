import '../models/location.dart';
import '../models/order.dart';
import '../utils/constants.dart';

/// One stop on the vendor's planned route.
class RouteStop {
  final FoodOrder order;
  final double distanceFromPreviousKm;
  final DateTime estimatedArrival;
  final bool isAtRiskOfLateness;

  /// Plain-language reason this stop is sequenced where it is — the
  /// "advice" the vendor sees under each stop, e.g. "Closest remaining
  /// stop" or "Placed here by 2-opt to avoid backtracking".
  final String reasoning;

  const RouteStop({
    required this.order,
    required this.distanceFromPreviousKm,
    required this.estimatedArrival,
    required this.isAtRiskOfLateness,
    this.reasoning = '',
  });
}

/// A batch of orders that share a delivery time-window, in the order the
/// vendor should visit them.
class TimeWindowGroup {
  final DateTime windowStart;
  final List<RouteStop> stops;

  const TimeWindowGroup({required this.windowStart, required this.stops});

  double get groupDistanceKm =>
      stops.fold(0.0, (sum, s) => sum + s.distanceFromPreviousKm);
}

/// The full plan the vendor follows: every pending order, grouped by when
/// it's needed and sequenced for shortest realistic travel within each
/// group, plus a summary of how much better this is than doing no
/// optimization at all.
class RoutePlan {
  final List<TimeWindowGroup> windows;

  /// What the total distance would have been if the vendor simply visited
  /// orders in the order they came in — no grouping, no sequencing. This is
  /// the baseline the "efficiency" stat is measured against.
  final double naiveDistanceKm;

  const RoutePlan({required this.windows, this.naiveDistanceKm = 0});

  double get totalDistanceKm =>
      windows.fold(0.0, (sum, w) => sum + w.groupDistanceKm);

  int get totalStops => windows.fold(0, (sum, w) => sum + w.stops.length);

  List<RouteStop> get flatStops => windows.expand((w) => w.stops).toList();

  List<RouteStop> get atRiskStops =>
      flatStops.where((s) => s.isAtRiskOfLateness).toList();

  /// How much shorter the optimized route is than the naive baseline, as a
  /// percentage. 0 if there's nothing to compare (e.g. a single stop).
  double get efficiencyPercent {
    if (naiveDistanceKm <= 0) return 0;
    final saved = naiveDistanceKm - totalDistanceKm;
    if (saved <= 0) return 0;
    return (saved / naiveDistanceKm) * 100;
  }

  /// Plain-language, prioritized advice for the vendor — generated fresh
  /// from whatever the plan actually looks like right now, not canned text.
  List<String> get vendorAdvice {
    final advice = <String>[];
    if (flatStops.isEmpty) return advice;

    if (atRiskStops.isNotEmpty) {
      final first = atRiskStops.first;
      advice.add(
        '${atRiskStops.length} ${atRiskStops.length == 1 ? 'delivery is' : 'deliveries are'} '
        'at risk of running late — starting with ${first.order.deliveryLocation.name} '
        'first would help most.',
      );
    }

    if (windows.isNotEmpty) {
      final tightest = windows.reduce(
        (a, b) => a.stops.length >= b.stops.length ? a : b,
      );
      if (tightest.stops.length > 1) {
        advice.add(
          'The ${_formatWindowLabel(tightest.windowStart)} batch has the most '
          'stops (${tightest.stops.length}) — cook and pack for that group '
          'first so it\'s ready the moment you head out.',
        );
      }
    }

    final longestLeg = flatStops.isEmpty
        ? null
        : flatStops.reduce(
            (a, b) =>
                a.distanceFromPreviousKm >= b.distanceFromPreviousKm ? a : b,
          );
    if (longestLeg != null && longestLeg.distanceFromPreviousKm > 0.5) {
      advice.add(
        'The longest single leg is ${longestLeg.distanceFromPreviousKm.toStringAsFixed(2)} km, '
        'to ${longestLeg.order.deliveryLocation.name} — worth calling ahead so '
        'they know you\'re on the way.',
      );
    }

    if (efficiencyPercent > 1) {
      advice.add(
        'This route is ${efficiencyPercent.toStringAsFixed(0)}% shorter than '
        'delivering in the order the orders came in — that\'s real walking '
        'time saved today.',
      );
    }

    return advice;
  }

  String _formatWindowLabel(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final period = t.hour < 12 ? 'AM' : 'PM';
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

/// Builds a delivery plan out of a pile of pending orders.
///
/// The logic runs in three steps:
///
/// 1. GROUP BY TIME. Orders are bucketed into fixed-size windows (default
///    30 min, see [AppConfig.deliveryWindowSize]) based on when the customer
///    wants their food, so the vendor cooks/packs for a batch of people
///    instead of running back and forth for each individual order.
///
/// 2. BUILD AN INITIAL ROUTE — nearest-neighbour. Within a time window,
///    starting from wherever the vendor will be, always go to the closest
///    not-yet-visited delivery point next. This is a classic greedy
///    travelling-salesman heuristic: fast, and usually decent, but it can
///    "paint itself into a corner" — visiting three close-together stops
///    while skipping a fourth right next door, only to double back for it
///    later.
///
/// 3. REFINE WITH 2-OPT. The nearest-neighbour route is then improved by
///    repeatedly testing every pair of stops: if reversing the segment
///    between them would shorten the total route distance, keep the swap.
///    This repeats until no swap helps anymore. It's the standard fix for
///    nearest-neighbour's "corner-painting" problem, needs no external
///    APIs or data, and runs instantly for the handful of stops a vendor
///    handles per batch.
///
/// Each stop's estimated arrival time is then calculated from the *final*
/// sequence, and flagged as "at risk" if it's projected to land more than
/// [AppConfig.latenessGraceMinutes] after the customer's preferred time.
class RouteOptimizerService {
  RoutePlan buildDeliveryPlan(
    List<FoodOrder> pendingOrders, {
    Location vendorStart = CampusLocations.vendorBase,
    Duration windowSize = AppConfig.deliveryWindowSize,
  }) {
    if (pendingOrders.isEmpty) {
      return const RoutePlan(windows: []);
    }

    final groupedByWindow = _groupByTimeWindow(pendingOrders, windowSize);
    final windowStarts = groupedByWindow.keys.toList()..sort();

    final windows = <TimeWindowGroup>[];
    Location currentPosition = vendorStart;
    DateTime currentTime = DateTime.now();

    for (final windowStart in windowStarts) {
      final ordersInWindow = groupedByWindow[windowStart]!;

      // Step 2: fast initial route.
      final nearestNeighbourRoute = _nearestNeighbourRoute(
        ordersInWindow,
        currentPosition,
      );

      // Step 3: refine it with 2-opt.
      final refinedRoute = _twoOptImprove(
        nearestNeighbourRoute,
        currentPosition,
      );

      final stops = <RouteStop>[];
      for (var i = 0; i < refinedRoute.length; i++) {
        final order = refinedRoute[i];
        final distanceKm = currentPosition.distanceToKm(order.deliveryLocation);
        final travelMinutes = (distanceKm / AppConfig.assumedSpeedKmh) * 60;
        final arrival = currentTime.add(
          Duration(minutes: travelMinutes.round()),
        );

        final lateBy = arrival.difference(order.preferredTime).inMinutes;
        final atRisk = lateBy > AppConfig.latenessGraceMinutes;

        stops.add(
          RouteStop(
            order: order,
            distanceFromPreviousKm: distanceKm,
            estimatedArrival: arrival,
            isAtRiskOfLateness: atRisk,
            reasoning: _explainStop(
              index: i,
              distanceKm: distanceKm,
              atRisk: atRisk,
              lateByMinutes: lateBy,
            ),
          ),
        );

        currentPosition = order.deliveryLocation;
        currentTime = arrival;
      }

      windows.add(TimeWindowGroup(windowStart: windowStart, stops: stops));
    }

    final naiveDistanceKm = _naiveDistance(pendingOrders, vendorStart);

    return RoutePlan(windows: windows, naiveDistanceKm: naiveDistanceKm);
  }

  /// What visiting every order in its original (unsequenced) order would
  /// have cost — the honest baseline the "% shorter" stat is measured
  /// against, so the efficiency claim is always about *this* batch of
  /// orders, never a made-up number.
  double _naiveDistance(List<FoodOrder> orders, Location start) {
    var total = 0.0;
    var current = start;
    for (final order in orders) {
      total += current.distanceToKm(order.deliveryLocation);
      current = order.deliveryLocation;
    }
    return total;
  }

  String _explainStop({
    required int index,
    required double distanceKm,
    required bool atRisk,
    required int lateByMinutes,
  }) {
    if (atRisk) {
      return 'At risk — projected $lateByMinutes min after the customer\'s '
          'preferred time. Consider calling ahead.';
    }
    if (index == 0) {
      return 'Closest stop to your starting point.';
    }
    if (distanceKm < 0.15) {
      return 'Right next to the previous stop — quick hop.';
    }
    return 'Placed here by the route optimizer to avoid backtracking.';
  }

  /// Buckets orders into fixed windows keyed by the *start* of the window
  /// their preferredTime falls into, e.g. with a 30-min window, 12:07 and
  /// 12:29 both land in the 12:00 bucket.
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

  /// Greedy nearest-neighbour ordering: repeatedly pick whichever remaining
  /// order's delivery point is closest to the current position.
  List<FoodOrder> _nearestNeighbourRoute(
    List<FoodOrder> orders,
    Location startPosition,
  ) {
    final remaining = List<FoodOrder>.from(orders);
    final route = <FoodOrder>[];
    Location current = startPosition;

    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) => current
            .distanceToKm(a.deliveryLocation)
            .compareTo(current.distanceToKm(b.deliveryLocation)),
      );
      final next = remaining.removeAt(0);
      route.add(next);
      current = next.deliveryLocation;
    }

    return route;
  }

  /// 2-opt local search: repeatedly try reversing every possible segment
  /// of the route, and keep the reversal if it shortens the total distance
  /// (start position included). Stops when a full pass finds no
  /// improvement. This is the standard refinement over nearest-neighbour —
  /// it fixes exactly the "skipped a close stop, had to double back"
  /// mistake nearest-neighbour is prone to.
  List<FoodOrder> _twoOptImprove(List<FoodOrder> route, Location start) {
    if (route.length < 3) return route;

    var best = List<FoodOrder>.from(route);
    var improved = true;

    while (improved) {
      improved = false;
      for (var i = 0; i < best.length - 1; i++) {
        for (var j = i + 1; j < best.length; j++) {
          final candidate = _reverseSegment(best, i, j);
          if (_routeDistance(candidate, start) < _routeDistance(best, start)) {
            best = candidate;
            improved = true;
          }
        }
      }
    }

    return best;
  }

  List<FoodOrder> _reverseSegment(List<FoodOrder> route, int i, int j) {
    final result = List<FoodOrder>.from(route);
    var left = i;
    var right = j;
    while (left < right) {
      final tmp = result[left];
      result[left] = result[right];
      result[right] = tmp;
      left++;
      right--;
    }
    return result;
  }

  double _routeDistance(List<FoodOrder> route, Location start) {
    var total = 0.0;
    var current = start;
    for (final order in route) {
      total += current.distanceToKm(order.deliveryLocation);
      current = order.deliveryLocation;
    }
    return total;
  }
}

    final naiveDistanceKm = _naiveDistance(pendingOrders, vendorStart);

    return RoutePlan(windows: windows, naiveDistanceKm: naiveDistanceKm);
  }

  // Ensure these private helper methods (_groupByTimeWindow, _nearestNeighbourRoute, 
  // _twoOptImprove, _explainStop, _naiveDistance) remain intact below...
}

/// --- ADD THESE COMPATIBILITY MAPPINGS FOR YOUR UI SCREENS ---

enum AdvisorySeverity { info, warning, critical }

class RouteAdvisory {
  final String message;
  final AdvisorySeverity severity;
  RouteAdvisory(this.message, this.severity);
}

class RouteConditions {
  final List<String> activeHazards = const [];
  const RouteConditions();
}

extension RoutePlanUiCompatibility on RoutePlan {
  // Fixes: The getter 'advisories' isn't defined for the type 'RoutePlan'
  List<RouteAdvisory> get advisories {
    return vendorAdvice.map((msg) {
      if (msg.contains('at risk') || msg.contains('late')) {
        return RouteAdvisory(msg, AdvisorySeverity.critical);
      } else if (msg.contains('longest single leg')) {
        return RouteAdvisory(msg, AdvisorySeverity.warning);
      }
      return RouteAdvisory(msg, AdvisorySeverity.info);
    }).toList();
  }

  // Fixes: The getter 'suggestedDelayMinutes' isn't defined for the type 'RoutePlan'
  int get suggestedDelayMinutes => 0; 

  // Fixes: The getter 'conditions' isn't defined for the type 'RoutePlan'
  RouteConditions get conditions => const RouteConditions();
}

extension RouteStopUiCompatibility on RouteStop {
  // Fixes: The getter 'reasonNote' isn't defined for the type 'RouteStop'
  String get reasonNote => reasoning;
}

