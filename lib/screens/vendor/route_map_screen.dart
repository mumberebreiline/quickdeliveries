import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/maps_service.dart';
import '../../services/route_optimizer_service.dart';
import '../../utils/helpers.dart';
import 'package:quickdeliveries/services/route_optimizer_service.dart';

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
              _AdvisoryPanel(plan: plan),
              SizedBox(
                height: 260,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: MapsService.toLatLng(vendorLocation),
                    initialZoom: 15.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.quickdeliveries',
                    ),
                    PolylineLayer(
                      polylines: MapsService.buildPolylines(
                        plan,
                        vendorLocation,
                      ),
                    ),
                    MarkerLayer(
                      markers: MapsService.buildMarkers(plan, vendorLocation),
                    ),
                  ],
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

/// The actual "what should I do right now" panel — severity-ranked,
/// actionable messages instead of a single passive summary line.
class _AdvisoryPanel extends StatelessWidget {
  final RoutePlan plan;

  const _AdvisoryPanel({required this.plan});

  Color _backgroundFor(AdvisorySeverity severity) {
    return switch (severity) {
      AdvisorySeverity.critical => Colors.red.shade50,
      AdvisorySeverity.warning => Colors.orange.shade50,
      AdvisorySeverity.info => Colors.green.shade50,
    };
  }

  Color _textFor(AdvisorySeverity severity) {
    return switch (severity) {
      AdvisorySeverity.critical => Colors.red.shade800,
      AdvisorySeverity.warning => Colors.deepOrange,
      AdvisorySeverity.info => Colors.green.shade800,
    };
  }

  IconData _iconFor(AdvisorySeverity severity) {
    return switch (severity) {
      AdvisorySeverity.critical => Icons.error,
      AdvisorySeverity.warning => Icons.warning_amber_rounded,
      AdvisorySeverity.info => Icons.check_circle,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Critical first, so the most important thing is never scrolled past.
    final sorted = List.of(plan.advisories)
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.suggestedDelayMinutes > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested: hold this batch about ${plan.suggestedDelayMinutes} '
                      'minutes before heading out',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final advisory in sorted)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _backgroundFor(advisory.severity),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _iconFor(advisory.severity),
                    size: 16,
                    color: _textFor(advisory.severity),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advisory.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textFor(advisory.severity),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
