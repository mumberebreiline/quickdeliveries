import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user_profile.dart';
import '../../models/order_model.dart';
import '../../services/user_service.dart';

// Lets a customer watch their own order move through
// pending -> assigned -> outForDelivery -> delivered,
// live, via a Firestore stream on that one order document. Different
// from order_screen.dart's OrdersScreen, which lists every past order —
// this is a single-order tracking view, e.g. opened right after
// checkout or tapped from that list.
class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  static const _steps = [
    OrderStatus.pending,
    OrderStatus.assigned,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  final _userService = UserService();
  AppUserProfile? _vendorProfile;
  AppUserProfile? _deliveryGuyProfile;
  String? _lastFetchedDeliveryGuyUid;

  @override
  void initState() {
    super.initState();
    // Fetched once — there's only one vendor account in the system, so
    // this never needs to change while this screen is open.
    _userService.getVendorProfile().then((profile) {
      if (mounted) setState(() => _vendorProfile = profile);
    });
  }

  /// The delivery guy assigned to this order can change over time (it's
  /// null until the admin assigns someone), so this re-fetches only when
  /// that actually changes, rather than on every single Firestore tick.
  void _maybeUpdateDeliveryGuyProfile(String? assignedTo) {
    if (assignedTo == _lastFetchedDeliveryGuyUid) return;
    _lastFetchedDeliveryGuyUid = assignedTo;
    if (assignedTo == null) {
      setState(() => _deliveryGuyProfile = null);
      return;
    }
    _userService.getProfile(assignedTo).then((profile) {
      if (mounted) setState(() => _deliveryGuyProfile = profile);
    });
  }

  String _stepLabel(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order placed';
      case OrderStatus.assigned:
        return 'Assigned to a delivery guy';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }

  Future<void> _call(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the phone dialer for $phone')),
      );
    }
  }

  Future<void> _text(
    BuildContext context,
    String? phone,
    String message,
  ) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open messages for $phone')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Status'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData ||
              !snapshot.data!.exists ||
              snapshot.data!.data() == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = FoodOrder.fromFirestore(
            snapshot.data!.id,
            snapshot.data!.data()!,
          );
          final currentIndex = _steps.indexOf(order.status);

          // Scheduled after the frame, not called directly during
          // build — this can trigger a setState, which build() itself
          // shouldn't do synchronously.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeUpdateDeliveryGuyProfile(order.assignedTo),
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, order.id.length < 6 ? order.id.length : 6).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _stepLabel(order.status),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                  final done = currentIndex >= 0 && i <= currentIndex;
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
              Text(
                'Preferred time: ${TimeOfDay.fromDateTime(order.preferredTime).format(context)}',
              ),
              const SizedBox(height: 16),
              ...order.items.map(
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i.quantity}x ${i.name}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: UGX ${order.total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              // Contact section — a real gap before this: the customer
              // had no way to reach anyone at all if something went
              // wrong with an order. Shows the delivery guy once one's
              // assigned (he's the one physically coming), and the
              // vendor always, as a general fallback.
              if (order.status != OrderStatus.cancelled) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Need help with this order?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_deliveryGuyProfile != null)
                  _ContactTile(
                    label: 'Your delivery guy',
                    name: _deliveryGuyProfile!.name ?? 'Delivery guy',
                    onCall: () => _call(context, _deliveryGuyProfile!.phone),
                    onText: () => _text(
                      context,
                      _deliveryGuyProfile!.phone,
                      'Hi, this is regarding my Quick Deliveries order to '
                      '${order.deliveryLocation.name}.',
                    ),
                  ),
                if (_vendorProfile != null)
                  _ContactTile(
                    label: 'Quick Deliveries',
                    name: _vendorProfile!.name ?? 'Vendor',
                    onCall: () => _call(context, _vendorProfile!.phone),
                    onText: () => _text(
                      context,
                      _vendorProfile!.phone,
                      'Hi, this is regarding my Quick Deliveries order to '
                      '${order.deliveryLocation.name}.',
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String label;
  final String name;
  final VoidCallback onCall;
  final VoidCallback onText;

  const _ContactTile({
    required this.label,
    required this.name,
    required this.onCall,
    required this.onText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Icon(Icons.person, color: Colors.white, size: 18),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(label, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.phone, color: Colors.green),
              tooltip: 'Call',
            ),
            IconButton(
              onPressed: onText,
              icon: const Icon(Icons.sms_outlined, color: Colors.blue),
              tooltip: 'Text',
            ),
          ],
        ),
      ),
    );
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
    final color = isDone ? Colors.deepPurple : Colors.grey.shade400;
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
              Container(width: 2, height: 28, color: color.withValues(alpha: 0.4)),
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
