import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../home/login_screen.dart';
import 'incoming_orders_screen.dart';
import 'route_map_screen.dart';
import 'delivery_history_screen.dart';
import 'hazards_screen.dart';

class VendorDashboardScreen extends StatelessWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeCount = context.watch<OrderProvider>().activeOrders.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
            const SizedBox(height: 20),
            _DashboardTile(
              icon: Icons.inbox,
              label: 'Incoming Orders',
              subtitle: 'Confirm and prepare new orders',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const IncomingOrdersScreen()),
              ),
            ),
            _DashboardTile(
              icon: Icons.map,
              label: "Today's Route",
              subtitle: 'Optimized delivery order and map',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RouteMapScreen()),
              ),
            ),
            _DashboardTile(
              icon: Icons.warning_amber_rounded,
              label: 'Route Hazards',
              subtitle: 'Flag problem spots for smarter routing',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HazardsScreen()),
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
          backgroundColor: Colors.deepPurple.withOpacity(0.15),
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
