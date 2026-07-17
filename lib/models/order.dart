import 'location.dart';
import 'order_item.dart';

enum OrderStatus {
  pending, // just placed, vendor hasn't confirmed yet
  confirmed, // vendor accepted it
  preparing, // food is being cooked/packed
  outForDelivery, // vendor is en route with it
  delivered,
  cancelled,
}

/// A customer's order: what they want, where it needs to go, and when they
/// want it. This is the object the route optimizer schedules and sequences.
class FoodOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;

  /// Where on campus this needs to be delivered.
  final Location deliveryLocation;

  /// When the customer wants to eat / receive the food.
  final DateTime preferredTime;

  final OrderStatus status;
  final DateTime createdAt;
  final String? notes;

  const FoodOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.deliveryLocation,
    required this.preferredTime,
    required this.createdAt,
    this.status = OrderStatus.pending,
    this.notes,
  });

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.subtotal);

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  FoodOrder copyWith({OrderStatus? status}) {
    return FoodOrder(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      deliveryLocation: deliveryLocation,
      preferredTime: preferredTime,
      createdAt: createdAt,
      status: status ?? this.status,
      notes: notes,
    );
  }

  factory FoodOrder.fromMap(Map<String, dynamic> map, String id) {
    return FoodOrder(
      id: id,
      customerId: map['customerId'] as String,
      customerName: map['customerName'] as String,
      customerPhone: map['customerPhone'] as String,
      items: (map['items'] as List)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      deliveryLocation: Location.fromMap(
        map['deliveryLocation'] as Map<String, dynamic>,
      ),
      preferredTime: DateTime.parse(map['preferredTime'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((e) => e.toMap()).toList(),
      'deliveryLocation': deliveryLocation.toMap(),
      'preferredTime': preferredTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }
}
