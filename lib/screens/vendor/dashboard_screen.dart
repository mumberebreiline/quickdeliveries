import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/email_service.dart';
import '../home/login_screen.dart';
import 'assign_orders_screen.dart';
import 'live_fleet_screen.dart';
import 'delivery_history_screen.dart';

/// The admin's home screen. She no longer delivers personally — her job
/// is deciding who does, via Assign Orders. Route Overview was removed
/// entirely (it duplicated what Assign Orders already needs to do, and
/// wasn't earning its own screen once she stopped following routes
/// herself) — route_map_screen.dart itself is now unused and can be
/// deleted from the project.
class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final activeCount = orderProvider.activeOrders.length;
    final activeOrdersError = orderProvider.activeOrdersError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // A direct test — bypasses order detection, Firestore profile
          // lookups, everything — and just tries to send one email
          // right now, straight to whoever's logged in. If this
          // doesn't work, the problem is in EmailJS setup or
          // email_service.dart itself, not anywhere else in the app.
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Send test email',
            onPressed: () async {
              final email = context.read<AuthProvider>().user?.email;
              if (email == null || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No email on this logged-in account to test with',
                    ),
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sending test email to $email...')),
              );
              final success = await EmailService().sendVendorNewOrderEmail(
                toEmail: email,
                toName: 'Test',
                customerName: 'Test Customer',
                destinationName: 'Test Location',
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Sent! Check $email (and Spam folder).'
                        : 'Failed to send — check the debug console for the exact reason.',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Active orders waiting',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (activeOrdersError != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Order count isn't updating: $activeOrdersError"
                        '${activeOrdersError.contains('index') ? '\n\nIf this mentions an "index", open the link Firestore printed in the debug console and click Create.' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _DashboardTile(
              icon: Icons.assignment_ind,
              label: 'Assign Orders',
              subtitle: 'Grouped by time hand batches to delivery guys',
              onTap: () => Navigator.push( 
                context,
                MaterialPageRoute(builder: (_) => const AssignOrdersScreen()),
              ),
            ),
            _DashboardTile(
              icon: Icons.pin_drop,
              label: 'Live Fleet',
              subtitle: 'See where each delivery guy is right now',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiveFleetScreen()),
              ),
            ),
            _DashboardTile(
              icon: Icons.history,
              label: 'Delivery History',
              subtitle: 'Past completed deliveries',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeliveryHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
