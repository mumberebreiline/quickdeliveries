import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/maps_service.dart';
import '../../services/route_optimizer_service.dart';
import '../../utils/helpers.dart';

/// The screen that makes the whole point of the app visible: today's
/// pending orders, grouped by time-window and sequenced by shortest travel
/// distance, shown as both a map and a checklist.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort GPS refresh; the plan still works fine off the fallback
    // vendor base location if this fails (e.g. no permission yet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().refreshOnce();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final vendorLocation = locationProvider.currentLocation;

    final RoutePlan plan = orderProvider.buildRoutePlan(vendorLocation);

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
        ],
      ),
      body: plan.windows.isEmpty
          ? const Center(child: Text('No active orders to route yet'))
          : Column(
              children: [
                SizedBox(
                  height: 280,
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
        'ETA ${formatTime(stop.estimatedArrival)}',
      ),
      trailing: stop.isAtRiskOfLateness
          ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
          : const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
