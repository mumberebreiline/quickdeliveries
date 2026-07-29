import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';

// Lets a customer watch their own order move through
// pending -> confirmed -> preparing -> outForDelivery -> delivered,
// live, via a Firestore stream on that one order document. Different
// from order_screen.dart's OrdersScreen, which lists every past order —
// this is a single-order tracking view, e.g. opened right after
// checkout or tapped from that list.
class OrderStatusScreen extends StatelessWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.assigned,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  String _stepLabel(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order placed';
      case OrderStatus.assigned:
        return 'Assigned to a delivery guy';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              !snapshot.data!.exists ||
              snapshot.data!.data() == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = FoodOrder.fromFirestore(
            snapshot.data!.id,
            snapshot.data!.data()!,
          );
          final currentIndex = _steps.indexOf(order.status);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, order.id.length < 6 ? order.id.length : 6).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _stepLabel(order.status),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (order.status == OrderStatus.cancelled)
                const Text(
                  'This order was cancelled.',
                  style: TextStyle(color: Colors.red),
                )
              else
                ...List.generate(_steps.length, (i) {
                  final done = currentIndex >= 0 && i <= currentIndex;
                  return _StepRow(
                    label: _stepLabel(_steps[i]),
                    isDone: done,
                    isLast: i == _steps.length - 1,
                  );
                }),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Delivering to: ${order.deliveryLocation.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Preferred time: ${TimeOfDay.fromDateTime(order.preferredTime).format(context)}',
              ),
              const SizedBox(height: 16),
              ...order.items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i.quantity}x ${i.name}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: UGX ${order.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isLast;

  const _StepRow({
    required this.label,
    required this.isDone,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? Colors.deepPurple : Colors.grey.shade400;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: color,
              size: 20,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: color.withValues(alpha: 0.4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            label,
            style: TextStyle(
              color: isDone ? Colors.black87 : Colors.grey,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
