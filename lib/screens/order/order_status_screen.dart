import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/status_badge.dart';

/// Lets a customer watch their own order move through
/// pending -> confirmed -> preparing -> out for delivery -> delivered,
/// live, via a Firestore stream.
///
/// The order is saved in the background (see OrderProvider.checkout), so
/// this screen may open a moment *before* the write has actually landed.
/// A brief "order not found" isn't a real error in that window — it only
/// becomes one if it's still missing after [_notFoundTimeout].
class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  static const _notFoundTimeout = Duration(seconds: 8);
  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(_notFoundTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.read<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          ),
        ),
      ),
      body: StreamBuilder<FoodOrder?>(
        stream: orderProvider.streamOrderById(widget.orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;

          if (order != null) {
            _timeoutTimer?.cancel(); // it showed up, no need to watch anymore
          }

          if (order == null) {
            if (_timedOut) {
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
                        "We couldn't confirm your order. Please check your "
                        'connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (route) => false,
                        ),
                        child: const Text('Back to menu'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const LoadingWidget(message: 'Placing your order...');
          }

          final currentIndex = _steps.indexOf(order.status);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  StatusBadge(status: order.status),
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
                  final done = i <= currentIndex;
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
              Text('Preferred time: ${formatTime(order.preferredTime)}'),
              const SizedBox(height: 16),
              ...order.items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i.quantity}x ${i.productName}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${formatUgx(order.totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );
  }

  String _stepLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order placed';
      case OrderStatus.confirmed:
        return 'Vendor confirmed';
      case OrderStatus.preparing:
        return 'Preparing your food';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
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
    final color = isDone ? const Color(0xFF1B5E20) : Colors.grey.shade400;
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
              Container(width: 2, height: 28, color: color.withOpacity(0.4)),
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
