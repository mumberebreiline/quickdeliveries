import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_service.dart';
import '../models/order_model.dart';
import '../models/location.dart';

// Handles talking to the "orders" collection in Firestore:
// saving a new order, fetching the logged-in user's past orders, and
// (new) giving the vendor a live feed of everything she still needs to
// act on, plus the ability to update an order's status.
class OrderService {
  static final _ordersCollection = FirebaseFirestore.instance.collection(
    'orders',
  );

  // Takes whatever is currently in the cart, saves it as one order
  // document, and empties the cart afterward.
  //
  // deliveryLocation/preferredTime are required now — the vendor's route
  // optimizer can't plan a delivery it doesn't know the destination or
  // timing for. Whichever screen calls this needs to collect those two
  // things from the customer first (a building picker + a time picker).
  static Future<void> placeOrder({
    required Location deliveryLocation,
    required DateTime preferredTime,
    required String customerName,
    required String customerPhone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to place an order.');
    }

    final cartItems = CartService.instance.items;
    if (cartItems.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    final order = FoodOrder(
      id: '', // Firestore assigns this
      userId: user.uid,
      customerName: customerName,
      customerPhone: customerPhone,
      items: cartItems
          .map(
            (item) => OrderItem(
              foodId: item.food.id,
              name: item.food.name,
              price: item.food.price,
              quantity: item.quantity,
            ),
          )
          .toList(),
      total: CartService.instance.totalPrice,
      createdAt: DateTime.now(),
      deliveryLocation: deliveryLocation,
      preferredTime: preferredTime,
    );

    await _ordersCollection.add(order.toMap());
    CartService.instance.clear();
  }

  // A LIVE list of the logged-in user's orders, newest first.
  // Because this is a Stream, the orders screen updates automatically
  // the moment something changes in the database — no manual refresh.
  static Stream<List<FoodOrder>> streamMyOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _ordersCollection
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Live feed of every order the vendor still needs to prepare/deliver —
  /// this is what the route optimizer consumes. Unlike streamMyOrders,
  /// this isn't scoped to one user; the vendor needs to see everyone's.
  static Stream<List<FoodOrder>> streamActiveOrdersForVendor() {
    return _ordersCollection
        .where('status', whereIn: OrderStatus.active)
        .orderBy('preferredTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Orders nobody's been assigned to yet — what the admin's grouping
  /// screen shows, ready to hand off to a delivery guy.
  static Stream<List<FoodOrder>> streamPendingOrders() {
    return _ordersCollection
        .where('status', isEqualTo: OrderStatus.pending)
        .orderBy('preferredTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Orders currently assigned to one specific delivery guy — assigned
  /// but not yet delivered. This is his whole home screen.
  static Stream<List<FoodOrder>> streamAssignedOrders(String deliveryGuyUid) {
    return _ordersCollection
        .where('assignedTo', isEqualTo: deliveryGuyUid)
        .where(
          'status',
          whereIn: [OrderStatus.assigned, OrderStatus.outForDelivery],
        )
        .orderBy('preferredTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  static Stream<List<FoodOrder>> streamDeliveredOrders() {
    return _ordersCollection
        .where('status', isEqualTo: OrderStatus.delivered)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  static Future<void> updateStatus(String orderId, String status) {
    return _ordersCollection.doc(orderId).update({'status': status});
  }

  /// Either the admin or the assigned delivery guy can cancel an order —
  /// this just sets the status; both streamPendingOrders and
  /// streamAssignedOrders already filter on status, so a cancelled
  /// order disappears from both of their screens on its own, no extra
  /// cleanup needed.
  static Future<void> cancelOrder(String orderId) {
    return updateStatus(orderId, OrderStatus.cancelled);
  }

  /// The admin hands an order (or a whole batch of them) to a specific
  /// delivery guy — this is what replaces the old manual "confirm/start
  /// preparing" steps. The order is treated as already confirmed the
  /// moment it's assigned.
  static Future<void> assignOrder({
    required String orderId,
    required String deliveryGuyUid,
    required String deliveryGuyName,
  }) {
    return _ordersCollection.doc(orderId).update({
      'assignedTo': deliveryGuyUid,
      'assignedToName': deliveryGuyName,
      'status': OrderStatus.assigned,
    });
  }
}
