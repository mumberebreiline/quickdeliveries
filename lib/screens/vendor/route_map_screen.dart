import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/maps_service.dart';
import '../../services/route_optimizer_service.dart';
import '../../utils/helpers.dart';

/// The screen that makes the whole point of the app visible: today's
/// pending orders, grouped by time-window, sequenced by a hazard-aware
/// 2-opt search, with ETAs adjusted for current weather/traffic — shown
/// as a map, a conditions summary, and a stop-by-stop explanation.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  Future<RoutePlan>? _planFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LocationProvider>().refreshOnce();
      _loadPlan();
    });
  }

  /// Fetching the plan makes a couple of network calls (weather, traffic)
  /// on top of reading Firestore hazards — so this runs once on load and
  /// again only when the vendor taps refresh, not on every rebuild.
  void _loadPlan() {
    if (!mounted) return;
    final orderProvider = context.read<OrderProvider>();
    final locationProvider = context.read<LocationProvider>();
    setState(() {
      _planFuture = orderProvider.buildRoutePlan(
        locationProvider.currentLocation,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Route"),
        actions: [
          IconButton(
            icon: Icon(
              locationProvider.isTracking
                  ? Icons.gps_fixed
                  : Icons.gps_not_fixed,
            ),
            tooltip: locationProvider.isTracking
                ? 'Stop live tracking'
                : 'Start live tracking',
            onPressed: () {
              if (locationProvider.isTracking) {
                locationProvider.stopTracking();
              } else {
                locationProvider.startTracking();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh conditions (weather, traffic, hazards)',
            onPressed: _loadPlan,
          ),
        ],
      ),
      body: FutureBuilder<RoutePlan>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Checking weather, traffic, and hazards...'),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not build a route: ${snapshot.error}'),
            );
          }

          final plan = snapshot.data;
          if (plan == null || plan.windows.isEmpty) {
            return const Center(child: Text('No active orders to route yet'));
          }

          final vendorLocation = locationProvider.currentLocation;

          return Column(
            children: [
              _ConditionsBanner(conditions: plan.conditions),
              SizedBox(
                height: 260,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: MapsService.toLatLng(vendorLocation),
                    zoom: 15.5,
                  ),
                  markers: MapsService.buildMarkers(plan, vendorLocation),
                  polylines: MapsService.buildPolylines(plan, vendorLocation),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${plan.totalStops} stops • '
                      '${plan.totalDistanceKm.toStringAsFixed(1)} km total',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (plan.atRiskStops.isNotEmpty)
                      Text(
                        '${plan.atRiskStops.length} at risk of lateness',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final window in plan.windows) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Batch: ${formatTime(window.windowStart)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      for (var i = 0; i < window.stops.length; i++)
                        _StopTile(index: i + 1, stop: window.stops[i]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Plain-language summary of the conditions the plan was built under —
/// this is the vendor-facing "why does the route look like this" answer.
class _ConditionsBanner extends StatelessWidget {
  final RouteConditions conditions;

  const _ConditionsBanner({required this.conditions});

  @override
  Widget build(BuildContext context) {
    if (!conditions.hasSlowdown && conditions.activeHazards.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        color: Colors.green.shade50,
        child: const Text(
          '✓ Clear conditions — no weather, traffic, or hazard delays factored in',
          style: TextStyle(fontSize: 12, color: Colors.green),
        ),
      );
    }

    final notes = <String>[];
    if (conditions.weather.isStorming || conditions.weather.isRaining) {
      notes.add(
        '${conditions.weather.description} — deliveries adjusted slower',
      );
    }
    if (conditions.trafficMultiplier > 1.05) {
      final percent = ((conditions.trafficMultiplier - 1) * 100).round();
      notes.add('Traffic is running ~$percent% slower than usual');
    }
    if (conditions.activeHazards.isNotEmpty) {
      notes.add('${conditions.activeHazards.length} flagged hazard(s) nearby');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: Colors.orange.shade50,
      child: Text(
        '⚠ ${notes.join(' • ')}',
        style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final int index;
  final RouteStop stop;

  const _StopTile({required this.index, required this.stop});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: stop.isAtRiskOfLateness
            ? Colors.red.shade100
            : Colors.green.shade100,
        child: Text('$index'),
      ),
      title: Text(stop.order.deliveryLocation.name),
      subtitle: Text(
        '${stop.order.customerName} • '
        '${stop.distanceFromPreviousKm.toStringAsFixed(2)} km • '
        'ETA ${formatTime(stop.estimatedArrival)}\n'
        '${stop.reasonNote}',
      ),
      isThreeLine: true,
      trailing: stop.isAtRiskOfLateness
          ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
          : const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
