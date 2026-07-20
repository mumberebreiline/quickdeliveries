import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/order_card.dart';

class IncomingOrdersScreen extends StatelessWidget {
  const IncomingOrdersScreen({super.key});

  String? _nextStatus(String current) {
    switch (current) {
      case OrderStatus.pending:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.outForDelivery;
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      default:
        return null;
    }
  }

  String _actionLabel(String current) {
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
    final error = orderProvider.activeOrdersError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Orders'),
        backgroundColor: Colors.deepPurple,
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Orders couldn't load",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If this mentions an "index", open the link Firestore printed '
                      'in the debug console and click Create — it takes a minute to '
                      'build, then this works permanently.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : orders.isEmpty
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
