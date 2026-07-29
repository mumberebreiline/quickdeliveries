import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../home/login_screen.dart';
import 'delivery_tracking_screen.dart';

/// The delivery guy's whole app, essentially — a list of what's been
/// assigned to him, and ONE button. Tapping it hands every currently
/// assigned stop to the tracking screen at once, which works out the
/// most time-efficient order to visit them in and then guides him
/// through all of them back to back — no returning here and tapping
/// Start again between deliveries.
class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  final _locationService = LocationService();
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    // A rough "where is he right now" ping, taken once when he opens
    // this screen — not continuous tracking. This is what lets the
    // admin's Assign Orders screen suggest the nearest delivery guy
    // even before anyone's actively out on a delivery (the tracking
    // screen already reports live position during an active trip; this
    // covers the gap while he's just waiting for one).
    _reportRoughLocation();
  }

  Future<void> _reportRoughLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final location = await _locationService.getCurrentLocation();
      await _userService.updateMyLocation(
        uid: uid,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (_) {
      // Not critical if this fails — the admin's screen just won't have
      // a distance to show for him until it succeeds.
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await AuthService().signOut();
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
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<FoodOrder>>(
              stream: OrderService.streamAssignedOrders(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Couldn't load your deliveries: ${snapshot.error}",
                        textAlign: TextAlign.center,
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
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nothing assigned to you right now.\n'
                        'Check back once the admin hands you a delivery.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final alreadyStarted = orders.any(
                  (o) => o.status == OrderStatus.outForDelivery,
                );

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];

                          // MergeSemantics combines the destination and
                          // customer name into ONE announcement for a
                          // screen reader, rather than two separate
                          // fragments per card.
                          return MergeSemantics(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.teal.shade50,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.teal,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            order.deliveryLocation.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 38),
                                      child: Text(
                                        order.customerName.isEmpty
                                            ? 'Customer'
                                            : order.customerName,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeliveryTrackingScreen(orders: orders),
                              ),
                            ),
                            icon: Icon(
                              alreadyStarted
                                  ? Icons.navigation
                                  : Icons.play_arrow,
                            ),
                            label: Text(
                              alreadyStarted
                                  ? 'Continue deliveries (${orders.length})'
                                  : 'Start deliveries (${orders.length})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
