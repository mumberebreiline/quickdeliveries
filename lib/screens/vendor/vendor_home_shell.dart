import 'package:flutter/material.dart';
import 'incoming_orders_screen.dart';
import 'route_map_screen.dart';
import 'delivery_history_screen.dart';

/// The vendor's persistent shell: one bottom nav bar, four tabs kept alive
/// underneath it via IndexedStack. Because all four tabs stay mounted
/// (just hidden), RouteMapScreen's live-traffic polling keeps running
/// even while the vendor is looking at a different tab — starting a
/// shift from Home doesn't require ever opening the Route tab.
class VendorHomeShell extends StatefulWidget {
  const VendorHomeShell({super.key});

  @override
  State<VendorHomeShell> createState() => _VendorHomeShellState();
}

class _VendorHomeShellState extends State<VendorHomeShell> {
  int _selectedIndex = 0;

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardHomeTab(onNavigateToTab: _goToTab),
      const IncomingOrdersScreen(),
      const RouteMapScreen(),
      const DeliveryHistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
