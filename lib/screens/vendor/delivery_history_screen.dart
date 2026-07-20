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
