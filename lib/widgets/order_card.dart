import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../utils/helpers.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  final FoodOrder order;
  final Widget? actions;

  const OrderCard({super.key, required this.order, this.actions});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName.isEmpty
                        ? 'Customer'
                        : order.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  order.deliveryLocation.name,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  formatTime(order.preferredTime),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.items.map((i) => '${i.quantity}x ${i.name}').join(', '),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              formatUgx(order.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (actions != null) ...[const SizedBox(height: 10), actions!],
          ],
        ),
      ),
    );
  }
}
