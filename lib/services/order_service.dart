import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_service.dart';
import '../models/order_model.dart';

// Handles talking to the "orders" collection in Firestore:
// saving a new order, and fetching the logged-in user's past orders.
class OrderService {
  static final _ordersCollection =
      FirebaseFirestore.instance.collection('orders');

  // Takes whatever is currently in the cart, saves it as one order
  // document, and empties the cart afterward.
  static Future<void> placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to place an order.');
    }

    final cartItems = CartService.instance.items;
    if (cartItems.isEmpty) {
      throw Exception('Your cart is empty.');
    }

    await _ordersCollection.add({
      // "userId" matters here — it's what your Firestore security
      // rules check to make sure people can only see their own orders.
      'userId': user.uid,
      'items': cartItems
          .map((item) => OrderItem(
                foodId: item.food.id,
                name: item.food.name,
                price: item.food.price,
                quantity: item.quantity,
              ).toMap())
          .toList(),
      'total': CartService.instance.totalPrice,
      'status': 'pending',
      // FieldValue.serverTimestamp() lets Firestore stamp the exact
      // time it received the order, instead of trusting the phone's clock.
      'createdAt': FieldValue.serverTimestamp(),
    });

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
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodOrder.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}