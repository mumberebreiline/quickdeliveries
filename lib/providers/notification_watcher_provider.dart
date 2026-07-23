import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/local_notification_service.dart';
import '../services/order_service.dart';

/// Watches Firestore order streams and fires a local notification the
/// moment something relevant changes — a new order for the vendor, or a
/// status change for a customer's own order. Two separate watchers, only
/// one of which should ever be active per device:
///
///  - The VENDOR watcher sees every active order (there's no per-vendor
///    filter yet, since this is a single-vendor app) — only start this
///    for the actual logged-in vendor, never for a customer's phone, or
///    every customer would get buzzed about every stranger's order.
///  - The CUSTOMER watcher only ever sees the current signed-in
///    account's own orders (streamMyOrders() already filters by uid),
///    so it's safe to run for anyone, vendor or guest.
class NotificationWatcherProvider extends ChangeNotifier {
  final LocalNotificationService _notifications;
  StreamSubscription<List<FoodOrder>>? _vendorSub;
  StreamSubscription<List<FoodOrder>>? _customerSub;

  Set<String>? _lastSeenActiveOrderIds;
  Map<String, String>? _lastSeenStatusByOrderId;

  NotificationWatcherProvider({LocalNotificationService? notifications})
    : _notifications = notifications ?? LocalNotificationService() {
    _notifications.initialize();
  }

  bool get isWatchingVendorOrders => _vendorSub != null;
  bool get isWatchingCustomerOrders => _customerSub != null;

  void startVendorWatcher() {
    if (_vendorSub != null) return; // already running
    _lastSeenActiveOrderIds = null;
    _vendorSub = OrderService.streamActiveOrdersForVendor().listen(
      (orders) {
        final currentIds = orders.map((o) => o.id).toSet();

        // Skip the very first snapshot — otherwise every order that
        // already existed when she opened the app would look "new."
        if (_lastSeenActiveOrderIds != null) {
          final newIds = currentIds.difference(_lastSeenActiveOrderIds!);
          for (final order in orders.where((o) => newIds.contains(o.id))) {
            final name = order.customerName.isEmpty
                ? 'A customer'
                : order.customerName;
            _notifications.show(
              title: 'New order!',
              body: '$name just placed an order — ${order.deliveryLocation.name}',
            );
          }
        }
        _lastSeenActiveOrderIds = currentIds;
      },
      onError: (Object error) {
        // This watcher has no screen of its own to show an error on —
        // without this, a Firestore problem (most commonly a missing
        // composite index) would fail completely silently, forever,
        // with zero way to know why notifications stopped arriving.
        // ignore: avoid_print
        print('Vendor notification watcher error: $error');
      },
    );
  }

  void startCustomerWatcher() {
    if (_customerSub != null) return; // already running
    _lastSeenStatusByOrderId = null;
    _customerSub = OrderService.streamMyOrders().listen(
      (orders) {
        final currentStatusById = {for (final o in orders) o.id: o.status};

        if (_lastSeenStatusByOrderId != null) {
          for (final order in orders) {
            final previousStatus = _lastSeenStatusByOrderId![order.id];
            if (previousStatus != null && previousStatus != order.status) {
              _notifications.show(
                title: 'Order update',
                body: 'Your order is now: ${_friendlyStatus(order.status)}',
              );
            }
          }
        }
        _lastSeenStatusByOrderId = currentStatusById;
      },
      onError: (Object error) {
        // Same reasoning as the vendor watcher above — no screen to
        // surface this on, so at minimum it needs to be visible in the
        // debug console rather than vanishing silently.
        // ignore: avoid_print
        print('Customer notification watcher error: $error');
      },
    );
  }

  void stopVendorWatcher() {
    _vendorSub?.cancel();
    _vendorSub = null;
    _lastSeenActiveOrderIds = null;
  }

  void stopCustomerWatcher() {
    _customerSub?.cancel();
    _customerSub = null;
    _lastSeenStatusByOrderId = null;
  }

  String _friendlyStatus(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed by the vendor';
      case OrderStatus.preparing:
        return 'Being prepared';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _vendorSub?.cancel();
    _customerSub?.cancel();
    super.dispose();
  }
}