import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/order_card.dart';

class DeliveryHistoryScreen extends StatelessWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<List<FoodOrder>>(
        stream: orderProvider.streamDeliveredOrders(),
        builder: (context, snapshot) {
          // Without this branch, any Firestore error (a missing index,
          // most commonly) left this screen stuck on "Loading
          // history..." forever, with nothing visible telling you
          // something was actually wrong — that's what "not responding"
          // looked like from the outside.
          if (snapshot.hasError) {
            return Center(
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
                      "History couldn't load",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'If this mentions an "index", open the link Firestore '
                      'printed in the debug console and click Create — it '
                      'takes a minute to build, then this works permanently.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const LoadingWidget(message: 'Loading history...');
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No deliveries yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) => OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}
