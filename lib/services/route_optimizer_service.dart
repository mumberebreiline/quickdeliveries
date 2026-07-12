import '../models/location.dart';
import '../models/order.dart';
import '../utils/constants.dart';

/// One stop on the vendor's planned route.
class RouteStop {
  final FoodOrder order;
  final double distanceFromPreviousKm;
  final DateTime estimatedArrival;
  final bool isAtRiskOfLateness;

  const RouteStop({
    required this.order,
    required this.distanceFromPreviousKm,
    required this.estimatedArrival,
    required this.isAtRiskOfLateness,
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
/// it's needed and sequenced by shortest travel path within each group.
class RoutePlan {
  final List<TimeWindowGroup> windows;

  const RoutePlan({required this.windows});

  double get totalDistanceKm =>
      windows.fold(0.0, (sum, w) => sum + w.groupDistanceKm);

  int get totalStops => windows.fold(0, (sum, w) => sum + w.stops.length);

  List<RouteStop> get flatStops => windows.expand((w) => w.stops).toList();

  List<RouteStop> get atRiskStops =>
      flatStops.where((s) => s.isAtRiskOfLateness).toList();
}

/// Builds a delivery plan out of a pile of pending orders.
///
/// The logic in two steps:
///
/// 1. GROUP BY TIME. Orders are bucketed into fixed-size windows (default
///    30 min, see [AppConfig.deliveryWindowSize]) based on when the customer
///    wants their food. This means the vendor cooks/packs for a batch of
///    people who all need food around the same time, instead of running
///    back and forth for each individual order.
///
/// 2. SEQUENCE WITHIN EACH WINDOW. Within a time window, stops are ordered
///    using a nearest-neighbour heuristic: starting from wherever the
///    vendor will be (their base, or the last stop of the previous window),
///    always go to the closest not-yet-visited delivery point next. This is
///    the same idea behind classic travelling-salesman heuristics — it
///    won't always find the mathematically shortest possible path, but for
///    a handful of stops on a compact campus it gets very close, runs
///    instantly, and needs no external API calls.
///
/// Each stop's estimated arrival time is calculated from cumulative
/// distance and [AppConfig.assumedSpeedKmh], and flagged as "at risk" if
/// it's projected to land more than [AppConfig.latenessGraceMinutes] after
/// the customer's preferred time — giving the vendor an early warning to
/// reorder, call the customer, or start cooking sooner.
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
      final sequenced = _nearestNeighbourRoute(ordersInWindow, currentPosition);

      final stops = <RouteStop>[];
      for (final order in sequenced) {
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
          ),
        );

        currentPosition = order.deliveryLocation;
        currentTime = arrival;
      }

      windows.add(TimeWindowGroup(windowStart: windowStart, stops: stops));
    }

    return RoutePlan(windows: windows);
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
}
