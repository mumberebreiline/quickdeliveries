import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/location.dart';
import '../../models/order_model.dart';
import '../../services/directions_service.dart';
import '../../services/location_service.dart';
import '../../services/order_service.dart';
import '../../services/user_service.dart';
import '../../utils/constants.dart';

/// Everything the delivery guy sees after tapping "Start" — a real,
/// traffic-aware road route on Google Maps, spoken turn-by-turn
/// directions (free, on-device text-to-speech — no API cost beyond the
/// Directions call itself), and live distance/time remaining. Arrival
/// is detected automatically (getting within [_arrivalRadiusKm] of the
/// destination marks the order delivered on its own) — no second
/// button, matching the one-button design this screen exists for.
///
/// Nothing here is tied to a specific person — whichever delivery guy
/// account is logged in gets guided to whichever order they were
/// assigned, however many delivery guys the admin has set up.
class DeliveryTrackingScreen extends StatefulWidget {
  final FoodOrder order;

  const DeliveryTrackingScreen({super.key, required this.order});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  static const _arrivalRadiusKm = 0.05; // ~50 metres
  static const _stepArrivalRadiusKm =
      0.03; // ~30 metres — close enough to a turn to call it "reached"

  final _locationService = LocationService();
  final _directionsService = DirectionsService();
  final _userService = UserService();
  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  RoadRoute? _route;
  double? _speedKmPerMinute; // derived once from the real traffic-aware route
  int _currentStepIndex = 0;
  String? _error;
  bool _hasArrived = false;
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _begin();
  }

  Future<void> _begin() async {
    // Treated as "on his way" from the moment he starts, matching the
    // simplified lifecycle — no separate manual step before this.
    if (widget.order.status != OrderStatus.outForDelivery) {
      await OrderService.updateStatus(
        widget.order.id,
        OrderStatus.outForDelivery,
      );
    }

    try {
      final initial = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _currentLocation = initial);
      _pushMyLocation(initial);
      await _fetchRoute(initial);
      _checkProgress(initial);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }

    _locationSub = _locationService.streamLocation().listen(
      (location) {
        if (!mounted) return;
        setState(() {
          _currentLocation = location;
          _error = null;
        });
        _pushMyLocation(location);
        _checkProgress(location);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  /// Fire-and-forget — the admin's fleet map doesn't need this to be
  /// perfectly synchronous, and there's no reason to block his own
  /// screen waiting for a Firestore write to confirm.
  void _pushMyLocation(Location location) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userService.updateMyLocation(
      uid: uid,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  Future<void> _fetchRoute(Location from) async {
    setState(() => _isLoadingRoute = true);
    try {
      final route = await _directionsService.getRoute([
        from,
        widget.order.deliveryLocation,
      ]);
      if (!mounted) return;
      setState(() {
        _route = route;
        _isLoadingRoute = false;
        _speedKmPerMinute = route.durationMinutes > 0
            ? route.distanceKm / route.durationMinutes
            : null;
      });
      if (route.steps.isNotEmpty) {
        _speak(route.steps.first.instruction);
      }
    } catch (e) {
      // Real route unavailable (no billing configured, network issue,
      // etc.) — fall back to a straight line and a speed-based estimate
      // rather than blocking the delivery guy from seeing anything.
      debugPrint('Directions fetch failed, falling back to straight line: $e');
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _speak(String instruction) async {
    await _tts.stop();
    await _tts.speak(instruction);
  }

  void _checkProgress(Location current) {
    if (_hasArrived) return;

    // Advance through spoken turn-by-turn steps as he actually reaches
    // each one — never re-announce a step he's already passed.
    final route = _route;
    if (route != null && _currentStepIndex < route.steps.length) {
      final nextStep = route.steps[_currentStepIndex];
      final stepLocation = Location(
        id: 'step',
        name: 'step',
        latitude: nextStep.latitude,
        longitude: nextStep.longitude,
      );
      if (current.distanceToKm(stepLocation) <= _stepArrivalRadiusKm) {
        _currentStepIndex++;
        if (_currentStepIndex < route.steps.length) {
          setState(() {});
          _speak(route.steps[_currentStepIndex].instruction);
        }
      }
    }

    final distanceKm = current.distanceToKm(widget.order.deliveryLocation);
    if (distanceKm <= _arrivalRadiusKm) {
      _hasArrived = true;
      _locationSub?.cancel();
      _tts.stop();
      OrderService.updateStatus(widget.order.id, OrderStatus.delivered);
      _clearMyLocation();
      if (mounted) {
        _speak('You have arrived at the delivery point.');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Arrived!'),
            content: const Text(
              'You\'ve reached the delivery point — this order has '
              'automatically been marked as delivered.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // back to the delivery list
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _clearMyLocation() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userService.clearMyLocation(uid);
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _tts.stop();
    // If he backs out mid-delivery rather than actually arriving, don't
    // leave a stale marker sitting on the admin's fleet map forever.
    if (!_hasArrived) _clearMyLocation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.order.deliveryLocation;
    final current = _currentLocation;

    final distanceKm = current?.distanceToKm(destination);
    final etaMinutes = distanceKm == null
        ? null
        : (_speedKmPerMinute != null && _speedKmPerMinute! > 0)
        ? distanceKm / _speedKmPerMinute!
        : (distanceKm / AppConfig.assumedSpeedKmh) * 60;

    final currentInstruction =
        (_route != null && _currentStepIndex < _route!.steps.length)
        ? _route!.steps[_currentStepIndex].instruction
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(destination.name),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.teal,
            child: current == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_error == null) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Finding your location...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ] else
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(
                            label: 'Distance left',
                            value:
                                '${distanceKm!.toStringAsFixed(distanceKm < 1 ? 2 : 1)} km',
                          ),
                          _StatColumn(
                            label: 'Time left',
                            value: etaMinutes! < 1
                                ? 'Almost there'
                                : '${etaMinutes.round()} min',
                          ),
                        ],
                      ),
                      if (currentInstruction != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.volume_up,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentInstruction,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_isLoadingRoute) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Getting turn-by-turn directions...',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
          ),
          Expanded(
            child: current == null
                ? const SizedBox.shrink()
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(current.latitude, current.longitude),
                      zoom: 16,
                    ),
                    myLocationEnabled: true,
                    polylines: {
                      if (_route != null)
                        Polyline(
                          polylineId: const PolylineId('delivery_route'),
                          points: _route!.points,
                          color: Colors.teal,
                          width: 5,
                        )
                      else
                        Polyline(
                          polylineId: const PolylineId(
                            'delivery_route_fallback',
                          ),
                          points: [
                            LatLng(current.latitude, current.longitude),
                            LatLng(destination.latitude, destination.longitude),
                          ],
                          color: Colors.teal,
                          width: 4,
                          patterns: [PatternItem.dash(12), PatternItem.gap(8)],
                        ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: LatLng(
                          destination.latitude,
                          destination.longitude,
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                        infoWindow: InfoWindow(title: destination.name),
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
