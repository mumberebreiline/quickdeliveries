import 'package:cloud_firestore/cloud_firestore.dart';
import 'location.dart';

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

/// Order status values, as plain strings (matching how this project
/// already writes 'pending' in OrderService) rather than an enum, so
/// nothing that already reads order.status as a String needs to change.
///
/// Simplified lifecycle, per the lecturer's requirement: a placed order
/// is treated as already confirmed — there's no separate manual
/// "confirm" or "start preparing" step anymore. The real steps now are
/// about who's handling it: unassigned, assigned to a delivery guy, out
/// for delivery, delivered.
class OrderStatus {
  /// Just placed, nobody assigned to it yet — this is what the admin's
  /// grouping screen shows.
  static const pending = 'pending';

  /// The admin has assigned this to a specific delivery guy, but he
  /// hasn't tapped "Start" yet.
  static const assigned = 'assigned';

  /// The delivery guy tapped Start and is on his way.
  static const outForDelivery = 'outForDelivery';

  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  /// Statuses that mean "this still needs to be delivered" — the feed
  /// the route optimizer and the admin's grouping screen both consume.
  static const active = [pending, assigned, outForDelivery];
}

// One whole order document from Firestore, including all its items.
//
// customerName/customerPhone/deliveryLocation/preferredTime are new —
// the original model only had userId, with no way to know *where* or
// *when* to deliver. Those are exactly what the route optimizer needs,
// so they're required going forward. Existing/older order documents that
// predate this (if any) will fall back to the vendor's own base location
// and "right now" — clearly wrong for routing, but keeps old data from
// crashing the parser; new orders should always supply real values.
//
// assignedTo/assignedToName are new too — which delivery guy (if any)
// this order has been handed to, and his name so screens don't need a
// separate lookup just to display who's carrying it.
class FoodOrder {
  final String id;
  final String userId;
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double total;
  final DateTime createdAt;
  final String status;
  final Location deliveryLocation;
  final DateTime preferredTime;
  final String? assignedTo;
  final String? assignedToName;

  FoodOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.createdAt,
    required this.deliveryLocation,
    required this.preferredTime,
    this.customerName = '',
    this.customerPhone = '',
    this.status = OrderStatus.pending,
    this.assignedTo,
    this.assignedToName,
  });

  factory FoodOrder.fromFirestore(String id, Map<String, dynamic> data) {
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return FoodOrder(
      id: id,
      userId: data['userId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      items: items,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      status: data['status'] as String? ?? OrderStatus.pending,
      deliveryLocation: data['deliveryLocation'] != null
          ? Location.fromMap(data['deliveryLocation'] as Map<String, dynamic>)
          : const Location(
              id: 'unknown',
              name: 'Unknown delivery point',
              latitude: 0.33280,
              longitude: 32.56750,
            ),
      preferredTime:
          _parseDate(data['preferredTime']) ??
          DateTime.now().add(const Duration(minutes: 30)),
      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
    );
  }

  /// Firestore normally stores these as a real Timestamp, written via
  /// FieldValue.serverTimestamp() or Timestamp.fromDate() — but a field
  /// added by hand through the Firestore Console UI (picking "string"
  /// instead of "timestamp" in the type dropdown, an easy mistake to
  /// make while testing) ends up as plain ISO text instead. Rather than
  /// crash on that, this accepts either shape.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryLocation': deliveryLocation.toMap(),
      'preferredTime': Timestamp.fromDate(preferredTime),
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
    };
  }
}
