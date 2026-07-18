import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';

// Displays the logged-in user's orders, fetched live from Firestore.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.orange,
      ),
      // StreamBuilder listens to OrderService.streamMyOrders() and
      // rebuilds this screen every time the data changes.
      body: StreamBuilder<List<FoodOrder>>(
        stream: OrderService.streamMyOrders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('You have no orders yet'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // ExpansionTile shows a summary, and opens up to reveal
                // the individual food items when tapped.
                child: ExpansionTile(
                  title: Text(
                    'Order #${order.id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${order.status} • \$${order.total.toStringAsFixed(2)}',
                  ),
                  children: order.items.map((item) {
                    return ListTile(
                      title: Text(item.name),
                      trailing: Text(
                        'x${item.quantity}   \$${item.subtotal.toStringAsFixed(2)}',
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}