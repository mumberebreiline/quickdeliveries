import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user_profile.dart';
import '../../models/location.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../services/order_service.dart';
import '../../services/email_service.dart';
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
  final _emailService = EmailService();

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

    // Email is a fallback that reaches him even if the app isn't open —
    // unlike the local push notification, which only fires if the app
    // process is alive. Doesn't block the assignment itself either way;
    // it already happened in Firestore above regardless of whether this
    // succeeds.
    if (deliveryGuy.email != null && deliveryGuy.email!.isNotEmpty) {
      _emailService.sendDeliveryAssignmentEmail(
        toEmail: deliveryGuy.email!,
        toName: deliveryGuy.name ?? 'there',
        destinationName: batch.first.deliveryLocation.name,
        stopCount: batch.length,
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
            stream: OrderService.streamOrdersInProgress(),
            builder: (context, inProgressSnapshot) {
              // Grouped by who it's assigned to, so each batch card can
              // look up "is this guy currently busy" in one map lookup
              // instead of scanning the whole list per dropdown item.
              final inProgressByGuy = <String, List<FoodOrder>>{};
              for (final order in inProgressSnapshot.data ?? <FoodOrder>[]) {
                if (order.assignedTo == null) continue;
                inProgressByGuy
                    .putIfAbsent(order.assignedTo!, () => [])
                    .add(order);
              }

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
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                        inProgressByGuy: inProgressByGuy,
                        onAssign: (guy) => _assignBatch(batch, guy),
                      );
                    },
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
  final Map<String, List<FoodOrder>> inProgressByGuy;
  final void Function(AppUserProfile) onAssign;

  const _BatchCard({
    required this.windowStart,
    required this.orders,
    required this.deliveryGuys,
    required this.inProgressByGuy,
    required this.onAssign,
  });

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  AppUserProfile? _selected;

  Future<void> _confirmCancel(BuildContext context, FoodOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'This cancels the order to ${order.deliveryLocation.name}'
          '${order.customerName.isEmpty ? '' : ' for ${order.customerName}'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await OrderService.cancelOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
      }
    }
  }

  /// How far a delivery guy's last-known position is from this batch —
  /// averaged across every stop in it, since a batch can have several.
  /// Null if he hasn't reported a location yet (never opened the app,
  /// or it failed silently) — those get sorted to the end rather than
  /// guessed at.
  double? _distanceKmFor(AppUserProfile guy) {
    if (guy.currentLatitude == null || guy.currentLongitude == null) {
      return null;
    }
    final guyLocation = Location(
      id: 'guy_${guy.uid}',
      name: 'guy',
      latitude: guy.currentLatitude!,
      longitude: guy.currentLongitude!,
    );
    final total = widget.orders.fold<double>(
      0.0,
      (sum, order) => sum + guyLocation.distanceToKm(order.deliveryLocation),
    );
    return total / widget.orders.length;
  }

  @override
  Widget build(BuildContext context) {
    final hour = widget.windowStart.hour.toString().padLeft(2, '0');
    final minute = widget.windowStart.minute.toString().padLeft(2, '0');

    // Nearest first, so the admin's first glance at the list already
    // suggests the sensible choice — someone with no location yet
    // (never reported one) goes to the bottom rather than being
    // guessed into a false "0 km away".
    final sortedGuys = List<AppUserProfile>.from(widget.deliveryGuys)
      ..sort((a, b) {
        final distA = _distanceKmFor(a);
        final distB = _distanceKmFor(b);
        if (distA == null && distB == null) return 0;
        if (distA == null) return 1;
        if (distB == null) return -1;
        return distA.compareTo(distB);
      });

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
            for (final order in widget.orders)
              OrderCard(
                order: order,
                actions: TextButton.icon(
                  onPressed: () => _confirmCancel(context, order),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text(
                    'Cancel order',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AppUserProfile>(
                    initialValue: _selected,
                    isExpanded: true,
                    // null lets each item size itself instead of being
                    // forced into the default single-line 48px height -
                    // needed now that each item shows two short lines
                    // instead of one long one.
                    itemHeight: null,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      helperText: 'Nearest first',
                      helperStyle: TextStyle(fontSize: 10),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: sortedGuys.map((guy) {
                      final distanceKm = _distanceKmFor(guy);
                      final distancePart = distanceKm == null
                          ? 'location unknown'
                          : '${distanceKm.toStringAsFixed(distanceKm < 1 ? 2 : 1)} km away';

                      // What this guy's currently doing, if anything -
                      // this is what stops the admin from handing more
                      // work to someone who's already physically out on
                      // a delivery right now, while still allowing more
                      // to be added to someone who's merely assigned
                      // but hasn't started yet.
                      final inProgress = widget.inProgressByGuy[guy.uid] ?? [];
                      final isOutForDelivery = inProgress.any(
                        (o) => o.status == OrderStatus.outForDelivery,
                      );
                      final assignedNotStarted = inProgress
                          .where((o) => o.status == OrderStatus.assigned)
                          .length;

                      final statusPart = isOutForDelivery
                          ? ' — out for delivery'
                          : assignedNotStarted > 0
                          ? ' — $assignedNotStarted assigned, not started'
                          : '';

                      return DropdownMenuItem(
                        value: guy,
                        enabled: !isOutForDelivery,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              guy.name ?? guy.uid,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isOutForDelivery ? Colors.grey : null,
                              ),
                            ),
                            Text(
                              '$distancePart$statusPart',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isOutForDelivery
                                    ? Colors.grey
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
