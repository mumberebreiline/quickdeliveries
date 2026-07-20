import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';

/// All Firestore reads/writes for orders live here, so the rest of the app
/// never talks to Firestore directly — it just calls plain Dart methods.
class OrderService {
  final CollectionReference<Map<String, dynamic>> _ordersRef = FirebaseFirestore
      .instance
      .collection('orders');

  /// The statuses that mean "the vendor still needs to act on this".
  static const List<OrderStatus> _activeStatuses = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.outForDelivery,
  ];

  Future<void> submitOrder(String orderId, FoodOrder order) {
    return _ordersRef.doc(orderId).set(order.toMap());
  }

  /// Live stream of every order the vendor still needs to prepare/deliver —
  /// this is the feed the route optimizer consumes.
  Stream<List<FoodOrder>> streamActiveOrders() {
    return _ordersRef
        .where('status', whereIn: _activeStatuses.map((s) => s.name).toList())
        .orderBy('preferredTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<FoodOrder>> streamDeliveredOrders() {
    return _ordersRef
        .where('status', isEqualTo: OrderStatus.delivered.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FoodOrder.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Lets a customer track a single order after checkout.
  Stream<FoodOrder?> streamOrderById(String orderId) {
    return _ordersRef.doc(orderId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FoodOrder.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> updateStatus(String orderId, OrderStatus status) {
    return _ordersRef.doc(orderId).update({'status': status.name});
  }
}
