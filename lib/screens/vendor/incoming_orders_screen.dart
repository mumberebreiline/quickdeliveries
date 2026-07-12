import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';

class IncomingOrdersScreen extends StatelessWidget {
  const IncomingOrdersScreen({super.key});

  OrderStatus? _nextStatus(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return null;
    }
  }

  String _actionLabel(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return 'Confirm';
      case OrderStatus.confirmed:
        return 'Start preparing';
      case OrderStatus.preparing:
        return 'Mark out for delivery';
      case OrderStatus.outForDelivery:
        return 'Mark delivered';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.activeOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Orders')),
      body: orders.isEmpty
          ? const Center(child: Text('No active orders right now'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final next = _nextStatus(order.status);

                return OrderCard(
                  order: order,
                  actions: next == null
                      ? null
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => orderProvider.updateStatus(
                                  order.id,
                                  OrderStatus.cancelled,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    orderProvider.updateStatus(order.id, next),
                                child: Text(_actionLabel(order.status)),
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }
}
