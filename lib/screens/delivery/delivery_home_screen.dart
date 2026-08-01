import 'dart:async';
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
  Timer? _locationPingTimer;
  DateTime? _lastReportedAt;

  @override
  void initState() {
    super.initState();
    // Ping once immediately, then keep re-pinging every couple of
    // minutes for as long as he has this screen open — not just once.
    // The Live Fleet screen only counts a location as current if it's
    // under 10 minutes old, so a single ping at app-open would quietly
    // go stale (and his marker would vanish) if he just sits here
    // waiting for the next assignment rather than actively delivering.
    _reportRoughLocation();
    _locationPingTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _reportRoughLocation(),
    );
  }

  @override
  void dispose() {
    _locationPingTimer?.cancel();
    super.dispose();
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
      if (mounted) setState(() => _lastReportedAt = DateTime.now());
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
          : Column(
              children: [
                _LocationSharingBanner(lastReportedAt: _lastReportedAt),
                Expanded(
                  child: StreamBuilder<List<FoodOrder>>(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor:
                                                    Colors.teal.shade50,
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
                                            padding: const EdgeInsets.only(
                                              left: 38,
                                            ),
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
                                      builder: (_) => DeliveryTrackingScreen(
                                        orders: orders,
                                      ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// A small, honest status line so he can see for himself that his
/// location really is being shared — not just something happening
/// invisibly in the background that he has to take on faith.
class _LocationSharingBanner extends StatelessWidget {
  final DateTime? lastReportedAt;
  const _LocationSharingBanner({required this.lastReportedAt});

  @override
  Widget build(BuildContext context) {
    final reported = lastReportedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: reported == null ? Colors.grey.shade200 : Colors.teal.shade50,
      child: Row(
        children: [
          Icon(
            reported == null ? Icons.location_disabled : Icons.location_on,
            size: 14,
            color: reported == null ? Colors.grey : Colors.teal,
          ),
          const SizedBox(width: 6),
          Text(
            reported == null
                ? 'Sharing your location with the admin...'
                : 'Your location is visible to the admin (updated just now)',
            style: TextStyle(
              fontSize: 11,
              color: reported == null
                  ? Colors.grey.shade700
                  : Colors.teal.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
