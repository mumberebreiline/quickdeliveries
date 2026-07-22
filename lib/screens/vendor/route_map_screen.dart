import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../../models/location.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/maps_service.dart';
import '../../services/osrm_service.dart';
import '../../services/route_optimizer_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/location_preview.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  RoutePlan? _plan;
  bool _isLoading = false;
  String? _error;
  OrderProvider? _orderProvider;

  final OsrmService _osrmService = OsrmService();
  // Real road-following lines, keyed by window index — filled in after
  // the plan loads. A window with no entry here just shows the
  // straight-line fallback instead (drawn by MapsService.buildPolylines).
  Map<int, Polyline> _roadPolylines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LocationProvider>().refreshOnce();
      _loadPlan();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<OrderProvider>();
    if (_orderProvider != provider) {
      _orderProvider?.removeListener(_onOrdersChanged);
      _orderProvider = provider;
      _orderProvider!.addListener(_onOrdersChanged);
    }
  }

  @override
  void dispose() {
    _orderProvider?.removeListener(_onOrdersChanged);
    super.dispose();
  }

  void _onOrdersChanged() {
    if (_plan == null || !mounted) return;
    final vendorLocation = context.read<LocationProvider>().currentLocation;
    final updated = _orderProvider!.tryInsertNewOrders(vendorLocation);
    if (updated != null) {
      setState(() => _plan = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New order added to your route'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadPlan() async {
    if (!mounted) return;
    final orderProvider = context.read<OrderProvider>();
    final locationProvider = context.read<LocationProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
      _roadPolylines = {};
    });
    try {
      final plan = await orderProvider.buildRoutePlan(
        locationProvider.currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
      _loadRoadPolylines(plan, locationProvider.currentLocation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Draws the actual road-following path for each batch, on top of the
  /// straight-line fallback already showing. Runs after the plan itself
  /// is on screen — the route doesn't need to wait on this, it's a
  /// visual refinement that fills in as each window resolves.
  Future<void> _loadRoadPolylines(RoutePlan plan, Location vendorStart) async {
    Location current = vendorStart;
    var windowIndex = 0;

    for (final window in plan.windows) {
      if (window.stops.isEmpty) {
        windowIndex++;
        continue;
      }

      final stops = [
        current,
        ...window.stops.map((s) => s.order.deliveryLocation),
      ];
      final capturedIndex = windowIndex;

      try {
        final road = await _osrmService.getRoute(stops);
        if (!mounted) return;
        setState(() {
          _roadPolylines = {
            ..._roadPolylines,
            capturedIndex: Polyline(
              points: road.points,
              color: MapsService.colorForWindow(capturedIndex),
              strokeWidth: 4,
            ),
          };
        });
      } catch (_) {
        // OSRM failed for this one window — leave it out of
        // _roadPolylines, so the straight-line fallback keeps showing
        // for just that window instead of breaking the whole map.
      }

      current = window.stops.last.order.deliveryLocation;
      windowIndex++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Route"),
        backgroundColor: Colors.deepPurple,
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
            tooltip: 'Refresh conditions (weather, traffic)',
            onPressed: _loadPlan,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading && _plan == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Checking weather and traffic...'),
                  ],
                ),
              ),
            );
          }
          if (_error != null) {
            return Center(child: Text('Could not build a route: $_error'));
          }

          final plan = _plan;
          if (plan == null || plan.windows.isEmpty) {
            return const Center(child: Text('No active orders to route yet'));
          }

          final vendorLocation = locationProvider.currentLocation;

          return ListView(
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
                      polylines: [
                        ...MapsService.buildPolylines(
                          plan,
                          vendorLocation,
                          skipWindows: _roadPolylines.keys.toSet(),
                        ),
                        ..._roadPolylines.values,
                      ],
                    ),
                    MarkerLayer(
                      markers: MapsService.buildMarkers(plan, vendorLocation),
                    ),
                  ],
                ),
              ),
              _EtaTimeline(plan: plan),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${plan.totalStops} stops • ${plan.totalDistanceKm.toStringAsFixed(1)} km total',
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
              if (plan.totalStops > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      plan.stopsWithRealRoadData == plan.totalStops
                          ? '✓ All distances from real road routes (OSRM)'
                          : '${plan.stopsWithRealRoadData} of ${plan.totalStops} stops using real road '
                                'routes — the rest are straight-line estimates',
                      style: TextStyle(
                        fontSize: 11,
                        color: plan.stopsWithRealRoadData == plan.totalStops
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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

class _EtaTimeline extends StatelessWidget {
  final RoutePlan plan;
  const _EtaTimeline({required this.plan});

  @override
  Widget build(BuildContext context) {
    final stops = plan.flatStops;
    if (stops.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < stops.length; i++) ...[
              _TimelineDot(index: i + 1, stop: stops[i]),
              if (i != stops.length - 1)
                Container(width: 28, height: 2, color: Colors.grey.shade300),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final int index;
  final RouteStop stop;
  const _TimelineDot({required this.index, required this.stop});

  @override
  Widget build(BuildContext context) {
    final color = stop.isAtRiskOfLateness ? Colors.red : Colors.green;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatTime(stop.estimatedArrival),
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

class _HealthScoreBadge extends StatelessWidget {
  final int score;
  final String label;
  const _HealthScoreBadge({required this.score, required this.label});

  Color get _color {
    if (score >= 85) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryPanel extends StatelessWidget {
  final RoutePlan plan;
  const _AdvisoryPanel({required this.plan});

  Color _backgroundFor(AdvisorySeverity s) => switch (s) {
    AdvisorySeverity.critical => Colors.red.shade50,
    AdvisorySeverity.warning => Colors.orange.shade50,
    AdvisorySeverity.info => Colors.green.shade50,
  };

  Color _textFor(AdvisorySeverity s) => switch (s) {
    AdvisorySeverity.critical => Colors.red.shade800,
    AdvisorySeverity.warning => Colors.deepOrange,
    AdvisorySeverity.info => Colors.green.shade800,
  };

  IconData _iconFor(AdvisorySeverity s) => switch (s) {
    AdvisorySeverity.critical => Icons.error,
    AdvisorySeverity.warning => Icons.warning_amber_rounded,
    AdvisorySeverity.info => Icons.check_circle,
  };

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(plan.advisories)
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HealthScoreBadge(
            score: plan.routeHealthScore,
            label: plan.routeHealthLabel,
          ),
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
                      'Suggested: hold this batch about ${plan.suggestedDelayMinutes} minutes before heading out',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A real aerial snapshot of the exact delivery spot — the
            // closest thing to "what does this place actually look
            // like" that's achievable for free (no billing, no key).
            LocationPreview(location: stop.order.deliveryLocation, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: stop.isAtRiskOfLateness
                            ? Colors.red.shade100
                            : Colors.green.shade100,
                        child: Text(
                          '$index',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stop.order.deliveryLocation.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      stop.isAtRiskOfLateness
                          ? const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 18,
                            )
                          : const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stop.order.customerName.isEmpty ? "Customer" : stop.order.customerName} • '
                    '${stop.distanceFromPreviousKm.toStringAsFixed(2)} km • '
                    'ETA ${formatTime(stop.estimatedArrival)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stop.reasonNote,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
