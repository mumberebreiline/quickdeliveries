import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../utils/helpers.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  final FoodOrder order;
  final Widget? actions;

  const OrderCard({super.key, required this.order, this.actions});

  Future<void> _callCustomer(BuildContext context) async {
    if (order.customerPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: order.customerPhone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the phone dialer for ${order.customerPhone}',
          ),
        ),
      );
    }
  }

  /// Opens the phone's own Messages app with a pre-filled text — this is
  /// the free alternative to real SMS sending (which would need a paid
  /// gateway like Africa's Talking plus a Cloud Functions backend).
  /// Nothing is sent automatically; whoever taps this still has to hit
  /// Send themselves, but it saves them typing out the message and
  /// looking up the number.
  Future<void> _textCustomer(BuildContext context) async {
    if (order.customerPhone.isEmpty) return;
    final message =
        'Hi ${order.customerName.isEmpty ? "" : order.customerName}, '
        'this is Quick Deliveries regarding your order to '
        '${order.deliveryLocation.name}.';
    final uri = Uri(
      scheme: 'sms',
      path: order.customerPhone,
      queryParameters: {'body': message},
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open messages for ${order.customerPhone}'),
        ),
      );
    }
  }

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
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: order.customerPhone.isEmpty
                        ? null
                        : () => _callCustomer(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: order.customerPhone.isEmpty
                              ? Colors.grey
                              : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            order.customerPhone.isEmpty
                                ? 'No phone number given'
                                : order.customerPhone,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: order.customerPhone.isEmpty
                                  ? Colors.grey
                                  : Colors.green.shade700,
                              decoration: order.customerPhone.isEmpty
                                  ? null
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.customerPhone.isNotEmpty)
                  IconButton(
                    onPressed: () => _textCustomer(context),
                    icon: Icon(
                      Icons.sms_outlined,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    tooltip: 'Text customer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryLocation.name,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
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
