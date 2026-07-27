import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user_profile.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../utils/constants.dart';
import '../../widgets/order_card.dart';

/// Replaces the old "Incoming Orders" screen. Instead of the admin
/// personally walking each order through confirm → preparing → out for
/// delivery, an order is now treated as already confirmed the moment
/// it's placed — her only real job is deciding who delivers it.
///
/// Orders are grouped automatically by preferred delivery time (same
/// 30-minute batching the route optimizer already uses) so she assigns
/// a whole batch to one delivery guy at once, rather than picking
/// through orders one at a time.
class AssignOrdersScreen extends StatefulWidget {
  const AssignOrdersScreen({super.key});

  @override
  State<AssignOrdersScreen> createState() => _AssignOrdersScreenState();
}

class _AssignOrdersScreenState extends State<AssignOrdersScreen> {
  final _userService = UserService();

  Map<DateTime, List<FoodOrder>> _groupByTimeWindow(List<FoodOrder> orders) {
    final map = <DateTime, List<FoodOrder>>{};
    final windowMinutes = AppConfig.deliveryWindowSize.inMinutes;
    for (final order in orders) {
      final t = order.preferredTime;
      final bucketMinute = (t.minute ~/ windowMinutes) * windowMinutes;
      final windowStart = DateTime(
        t.year,
        t.month,
        t.day,
        t.hour,
        bucketMinute,
      );
      map.putIfAbsent(windowStart, () => []).add(order);
    }
    return map;
  }

  Future<void> _assignBatch(
    List<FoodOrder> batch,
    AppUserProfile deliveryGuy,
  ) async {
    for (final order in batch) {
      await OrderService.assignOrder(
        orderId: order.id,
        deliveryGuyUid: deliveryGuy.uid,
        deliveryGuyName: deliveryGuy.name ?? 'Delivery guy',
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${batch.length} order(s) assigned to ${deliveryGuy.name ?? "delivery guy"}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Orders'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<List<AppUserProfile>>(
        stream: _userService.streamDeliveryGuys(),
        builder: (context, deliveryGuysSnapshot) {
          final deliveryGuys = deliveryGuysSnapshot.data ?? [];

          return StreamBuilder<List<FoodOrder>>(
            stream: OrderService.streamPendingOrders(),
            builder: (context, snapshot) {
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
                          "Orders couldn't load",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
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
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data!;
              if (orders.isEmpty) {
                return const Center(
                  child: Text('No unassigned orders right now'),
                );
              }

              if (deliveryGuys.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'There are unassigned orders, but no delivery guy accounts '
                      'exist yet. Add one in Firebase Console → Authentication, '
                      'then tag their users/{uid} document with role: "deliveryGuy" '
                      'in Firestore.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final grouped = _groupByTimeWindow(orders);
              final windowStarts = grouped.keys.toList()..sort();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: windowStarts.length,
                itemBuilder: (context, index) {
                  final windowStart = windowStarts[index];
                  final batch = grouped[windowStart]!;
                  return _BatchCard(
                    windowStart: windowStart,
                    orders: batch,
                    deliveryGuys: deliveryGuys,
                    onAssign: (guy) => _assignBatch(batch, guy),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BatchCard extends StatefulWidget {
  final DateTime windowStart;
  final List<FoodOrder> orders;
  final List<AppUserProfile> deliveryGuys;
  final void Function(AppUserProfile) onAssign;

  const _BatchCard({
    required this.windowStart,
    required this.orders,
    required this.deliveryGuys,
    required this.onAssign,
  });

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  AppUserProfile? _selected;

  @override
  Widget build(BuildContext context) {
    final hour = widget.windowStart.hour.toString().padLeft(2, '0');
    final minute = widget.windowStart.minute.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Text(
                  'Batch: $hour:$minute — ${widget.orders.length} order(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final order in widget.orders) OrderCard(order: order),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AppUserProfile>(
                    initialValue: _selected,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.deliveryGuys
                        .map(
                          (guy) => DropdownMenuItem(
                            value: guy,
                            child: Text(guy.name ?? guy.uid),
                          ),
                        )
                        .toList(),
                    onChanged: (guy) => setState(() => _selected = guy),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () => widget.onAssign(_selected!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Assign'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
