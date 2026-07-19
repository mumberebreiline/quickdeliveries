import 'package:cloud_firestore/cloud_firestore.dart';

// One food line inside an order (name, price, quantity at the time
// the order was placed — kept separate from FoodItem in case prices
// change later, so old orders still show what was actually paid).
class OrderItem {
  final String foodId;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() => {
        'foodId': foodId,
        'name': name,
        'price': price,
        'quantity': quantity,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      foodId: map['foodId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

// One whole order document from Firestore, including all its items.
class FoodOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double total;
  final DateTime createdAt;
  final String status;final String customerName;
  final String phoneNumber;

  final double latitude;
  final double longitude;

  final String preferredDeliveryTime;

  FoodOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.createdAt,
    this.status = 'pending',
  });

  factory FoodOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return FoodOrder(
      id: id,
      userId: data['userId'] as String? ?? '',
      items: items,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      // Firestore stores dates as Timestamp — this converts it to a
      // normal Dart DateTime so it's easy to work with.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
    );
  }
}