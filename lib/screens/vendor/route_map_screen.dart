import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/maps_service.dart';
import '../../services/directions_service.dart';
import '../../models/route_alternative.dart';
import '../../services/route_optimizer_service.dart';
import '../../utils/helpers.dart';
import '../../providers/route_savings_provider.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final DirectionsService _directionsService = DirectionsService();

  // How often to re-check live traffic while the vendor is out delivering.
  // Every 3 minutes keeps well inside the free monthly Directions quota
  // for a project this size, while still catching a jam forming.
  static const Duration _pollInterval = Duration(minutes: 3);

  Timer? _pollTimer;
  bool _wasTracking = false; // used to detect tracking turning on/off

  List<RouteAlternative> _alternatives = [];
  RouteAlternative? _selectedAlternative;
  bool _isCheckingRoutes = false;
  String? _routeCheckError;
  String? _lastCheckedStopId; // avoids re-checking the same stop pointlessly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().refreshOnce();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Turns automatic polling on/off in step with the vendor's live
  /// tracking toggle. Called every build — cheap to call repeatedly since
  /// it only actually starts/stops the timer when tracking state flips.
  void _syncPolling(bool isTracking, RouteStop? nextStop) {
    if (isTracking && !_wasTracking) {
      // Tracking just turned on — check immediately, then keep checking
      // on the timer, no need to wait for the first interval to elapse.
      _wasTracking = true;
      if (nextStop != null) _checkForFasterRoute(nextStop);
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        final currentNextStop = context.read<OrderProvider>()
            .buildRoutePlan(context.read<LocationProvider>().currentLocation)
            .flatStops
            .firstOrNull;
        if (currentNextStop != null) {
          _checkForFasterRoute(currentNextStop);
        }
      });
    } else if (!isTracking && _wasTracking) {
      // Tracking turned off — stop polling and clear stale suggestions.
      _wasTracking = false;
      _pollTimer?.cancel();
      _pollTimer = null;
      setState(() {
        _alternatives = [];
        _selectedAlternative = null;
        _lastCheckedStopId = null;
      });
    } else if (isTracking &&
        nextStop != null &&
        nextStop.order.id != _lastCheckedStopId) {
      // Vendor completed a delivery and moved on to a new next stop —
      // check the new leg right away instead of waiting for the timer.
      _checkForFasterRoute(nextStop);
    }
  }

  Future<void> _checkForFasterRoute(RouteStop nextStop) async {
    final vendorLocation = context.read<LocationProvider>().currentLocation;

    setState(() {
      _isCheckingRoutes = true;
      _routeCheckError = null;
      _lastCheckedStopId = nextStop.order.id;
    });

    try {
      final options = await _directionsService.getRouteOptions(
        origin: vendorLocation,
        destination: nextStop.order.deliveryLocation,
      );
      options.sort((a, b) =>
          a.durationInTrafficMinutes.compareTo(b.durationInTrafficMinutes));

      if (!mounted) return;
      setState(() {
        _alternatives = options;
        _selectedAlternative = options.isNotEmpty ? options.first : null;
      });

      // NEW — these two lines go right here, after the setState() above:
      if (!mounted) return;
      context.read<RouteSavingsProvider>().recordCheck(options);

    } catch (e) {
      if (!mounted) return;
      setState(() => _routeCheckError = e.toString());
    } finally {
      if (mounted) setState(() => _isCheckingRoutes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final vendorLocation = locationProvider.currentLocation;

    final RoutePlan plan = orderProvider.buildRoutePlan(vendorLocation);
    final RouteStop? nextStop =
        plan.flatStops.isNotEmpty ? plan.flatStops.first : null;

    // Keep the polling timer in sync with tracking state and current stop,
    // every build — cheap no-op unless something actually changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPolling(locationProvider.isTracking, nextStop);
    });

    final markers = MapsService.buildMarkers(plan, vendorLocation);
    final polylines = MapsService.buildPolylines(plan, vendorLocation);

    if (_selectedAlternative != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('live_suggested_route'),
          points: _selectedAlternative!.polylinePoints,
          color: Colors.blueAccent,
          width: 6,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Route"),
        actions: [
          IconButton(
            icon: Icon(locationProvider.isTracking
                ? Icons.gps_fixed
                : Icons.gps_not_fixed),
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
                  height: 260,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: MapsService.toLatLng(vendorLocation),
                      zoom: 15.5,
                    ),
                    markers: markers,
                    polylines: polylines,
                  ),
                ),

                // Only appears once tracking is on AND there's something
                // to show — fully automatic, nothing to tap.
                if (locationProvider.isTracking && nextStop != null)
                  _buildLiveRoutePanel(nextStop),

                const Divider(height: 1),
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
                                fontWeight: FontWeight.bold, fontSize: 15),
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

  /// Fully passive display — no button. Shows a small "checking..."
  /// indicator while a background poll is in flight, then the route
  /// cards once results are back. Updates by itself on the timer.
  Widget _buildLiveRoutePanel(RouteStop nextStop) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next: ${nextStop.order.deliveryLocation.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_isCheckingRoutes)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.sync, size: 16, color: Colors.grey.shade500),
            ],
          ),
          if (_routeCheckError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Live route check unavailable: $_routeCheckError',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (_alternatives.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _alternatives.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final option = _alternatives[index];
                  final isFastest = index == 0;
                  final isSelected = option == _selectedAlternative;

                  return _RouteOptionCard(
                    option: option,
                    isFastest: isFastest,
                    isSelected: isSelected,
                    minutesSavedVsSlowest: _alternatives.last
                            .durationInTrafficMinutes -
                        option.durationInTrafficMinutes,
                    onTap: () => setState(() => _selectedAlternative = option),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final RouteAlternative option;
  final bool isFastest;
  final bool isSelected;
  final int minutesSavedVsSlowest;
  final VoidCallback onTap;

  const _RouteOptionCard({
    required this.option,
    required this.isFastest,
    required this.isSelected,
    required this.minutesSavedVsSlowest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${option.durationInTrafficMinutes} min',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            if (isFastest && minutesSavedVsSlowest > 0)
              Text(
                '⚡ Save $minutesSavedVsSlowest min',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.orangeAccent : Colors.orange[800],
                ),
              )
            else if (option.trafficDelayMinutes > 2)
              Text(
                '+${option.trafficDelayMinutes} min traffic',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white70 : Colors.redAccent,
                ),
              ),
          ],
        ),
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
        backgroundColor:
            stop.isAtRiskOfLateness ? Colors.red.shade100 : Colors.green.shade100,
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