import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/route_optimizer_service.dart';

/// Vendor-facing order state: the live feed of active orders, and the
/// route plan built from them. Customer-side ordering keeps using
/// OrderService's static methods directly (streamMyOrders/placeOrder) —
/// this provider is additive, for the vendor screens only.
class OrderProvider extends ChangeNotifier {
  final RouteOptimizerService _routeOptimizer;
  StreamSubscription<List<FoodOrder>>? _activeOrdersSub;

  OrderProvider({RouteOptimizerService? routeOptimizer})
    : _routeOptimizer = routeOptimizer ?? RouteOptimizerService() {
    _listenToActiveOrders();
  }

  List<FoodOrder> _activeOrders = [];
  List<FoodOrder> get activeOrders => _activeOrders;

  /// Set if the live feed fails — most commonly a missing Firestore
  /// composite index (status + preferredTime) the first time this runs.
  String? _activeOrdersError;
  String? get activeOrdersError => _activeOrdersError;

  void _listenToActiveOrders() {
    _activeOrdersSub = OrderService.streamActiveOrdersForVendor().listen(
      (orders) {
        _activeOrders = orders;
        _activeOrdersError = null;
        notifyListeners();
      },
      onError: (Object error) {
        _activeOrdersError = error.toString();
        // ignore: avoid_print
        print('Active orders stream error: $error');
        notifyListeners();
      },
    );
  }

  Stream<List<FoodOrder>> streamDeliveredOrders() =>
      OrderService.streamDeliveredOrders();

  Future<void> updateStatus(String orderId, String status) {
    return OrderService.updateStatus(orderId, status);
  }

  RoutePlan? _cachedPlan;
  Set<String> _cachedPlanOrderIds = {};

  Future<RoutePlan> buildRoutePlan(Location vendorLocation) async {
    final plan = await _routeOptimizer.buildDeliveryPlan(
      _activeOrders,
      vendorStart: vendorLocation,
    );
    _cachedPlan = plan;
    _cachedPlanOrderIds = _activeOrders.map((o) => o.id).toSet();
    return plan;
  }

  /// Cheap, no-network-call check for orders that arrived since the plan
  /// was last built — slots them in via cheapest insertion instead of
  /// waiting for a manual refresh. Returns null if nothing new.
  RoutePlan? tryInsertNewOrders(Location vendorLocation) {
    if (_cachedPlan == null) return null;
    final newOrders = _activeOrders
        .where((o) => !_cachedPlanOrderIds.contains(o.id))
        .toList();
    if (newOrders.isEmpty) return null;

    var plan = _cachedPlan!;
    for (final order in newOrders) {
      plan = _routeOptimizer.insertOrderIntoPlan(
        plan,
        order,
        vendorStart: vendorLocation,
      );
    }
    _cachedPlan = plan;
    _cachedPlanOrderIds = _activeOrders.map((o) => o.id).toSet();
    return plan;
  }

  @override
  void dispose() {
    _activeOrdersSub?.cancel();
    super.dispose();
  }
}
