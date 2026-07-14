import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/location.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../services/order_service.dart';
import '../services/route_optimizer_service.dart';

/// One line in the customer's in-progress cart, before it becomes an order.
class CartLine {
  final Product product;
  int quantity;

  CartLine({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

/// The central provider for everything order-related:
///  - the customer's cart, before checkout
///  - submitting a finished order to Firestore
///  - the vendor's live feed of orders that still need action
///  - turning that feed into an optimized [RoutePlan]
class OrderProvider extends ChangeNotifier {
  final OrderService _orderService;
  final RouteOptimizerService _routeOptimizer;
  StreamSubscription<List<FoodOrder>>? _activeOrdersSub;

  OrderProvider({
    OrderService? orderService,
    RouteOptimizerService? routeOptimizer,
  }) : _orderService = orderService ?? OrderService(),
       _routeOptimizer = routeOptimizer ?? RouteOptimizerService() {
    _listenToActiveOrders();
  }

  // ---- Cart (customer side) -------------------------------------------

  final Map<String, CartLine> _cart = {};

  Map<String, CartLine> get cart => Map.unmodifiable(_cart);

  int get cartItemCount =>
      _cart.values.fold(0, (sum, line) => sum + line.quantity);

  double get cartTotal =>
      _cart.values.fold(0.0, (sum, line) => sum + line.subtotal);

  void addToCart(Product product) {
    if (_cart.containsKey(product.id)) {
      _cart[product.id]!.quantity++;
    } else {
      _cart[product.id] = CartLine(product: product);
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      _cart.remove(productId);
    } else if (_cart.containsKey(productId)) {
      _cart[productId]!.quantity = quantity;
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Turns the current cart into an order. Returns the new order's id
  /// *immediately* — the Firestore write happens in the background, so the
  /// customer isn't stuck staring at a spinner while the network round-trips.
  /// If the write fails, [onError] fires (the tracking screen also has its
  /// own timeout as a backstop in case this never resolves either way).
  String checkout({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required Location deliveryLocation,
    required DateTime preferredTime,
    String? notes,
    void Function(Object error)? onError,
  }) {
    final items = _cart.values
        .map(
          (line) => OrderItem(
            productId: line.product.id,
            productName: line.product.name,
            quantity: line.quantity,
            unitPrice: line.product.price,
          ),
        )
        .toList();

    final orderId = const Uuid().v4();

    final order = FoodOrder(
      id: orderId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      deliveryLocation: deliveryLocation,
      preferredTime: preferredTime,
      createdAt: DateTime.now(),
      notes: notes,
    );

    // Fire-and-forget: don't make the customer wait on this.
    _orderService.submitOrder(orderId, order).catchError((error) {
      onError?.call(error);
    });

    clearCart();
    return orderId;
  }

  // ---- Vendor side: active orders + route plan -------------------------

  List<FoodOrder> _activeOrders = [];
  List<FoodOrder> get activeOrders => _activeOrders;

  /// Set if the live orders feed fails — most commonly because Firestore
  /// needs a composite index for this query (status + preferredTime) and
  /// it hasn't been created yet. Previously this error was swallowed
  /// silently, which looked exactly like "no orders ever arrive."
  String? _activeOrdersError;
  String? get activeOrdersError => _activeOrdersError;

  void _listenToActiveOrders() {
    _activeOrdersSub = _orderService.streamActiveOrders().listen(
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
      _orderService.streamDeliveredOrders();

  Stream<FoodOrder?> streamOrderById(String orderId) =>
      _orderService.streamOrderById(orderId);

  Future<void> updateStatus(String orderId, OrderStatus status) {
    return _orderService.updateStatus(orderId, status);
  }

  /// Builds today's delivery plan out of whatever orders are currently
  /// active, starting from wherever the vendor currently is. Async now,
  /// since it checks live weather/traffic/hazard conditions before
  /// sequencing — call this once (e.g. on screen load or a manual
  /// refresh button), not on every rebuild.
  Future<RoutePlan> buildRoutePlan(Location vendorLocation) {
    return _routeOptimizer.buildDeliveryPlan(
      _activeOrders,
      vendorStart: vendorLocation,
    );
  }

  @override
  void dispose() {
    _activeOrdersSub?.cancel();
    super.dispose();
  }
}
