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
import '../../services/weather_service.dart';
import '../../services/route_optimizer_service.dart'
    show AdvisoryMessage, AdvisorySeverity, RouteOptimizerService;
import '../../utils/constants.dart';

/// Everything the delivery guy sees after tapping "Start" — laid out like
/// a real navigation app: the map fills almost the whole screen, and a
/// compact panel at the bottom shows distance left, time left, and a way
/// out (Cancel) — not stacked on top the way it was before.
///
/// Real, traffic-aware road route on Google Maps, spoken turn-by-turn
/// directions (free, on-device text-to-speech), and live distance/time
/// remaining. Arrival is detected automatically (getting within
/// [_arrivalRadiusKm] of the destination marks the order delivered on
/// its own) — no second "mark delivered" button.
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
  final _weatherService = WeatherService();
  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  RoadRoute? _route;
  double? _speedKmPerMinute; // derived once from the real traffic-aware route
  int _currentStepIndex = 0;
  String? _error;
  bool _hasArrived = false;
  bool _isLoadingRoute = true;
  bool _isCancelling = false;

  // Weather/night-safety advisories — this was the vendor's route-
  // overview information before, moved here since he's the one actually
  // out in it now, not her. Spoken aloud once at the start (not on every
  // GPS tick), which is also what makes this usable without looking at
  // the screen at all.
  List<AdvisoryMessage> _advisories = [];

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
      await _loadAdvisories(initial);
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

  Future<void> _loadAdvisories(Location location) async {
    final weather = await _weatherService.getCurrentConditions(location);
    final hour = DateTime.now().hour;
    final isNightNow = hour >= 19 || hour < 6;

    final advisories = RouteOptimizerService.personalSafetyAdvisories(
      weather: weather,
      isNightNow: isNightNow,
    );
    if (!mounted) return;
    setState(() => _advisories = advisories);

    // Read out anything that isn't just "conditions look clear" — no
    // need to narrate good news, but a storm/rain/night warning matters
    // enough to say out loud before he even starts moving.
    final worthSpeaking = advisories.where(
      (a) => a.severity != AdvisorySeverity.info,
    );
    for (final advisory in worthSpeaking) {
      await _speak(advisory.message);
    }
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

  /// Lets him re-hear the current advisories and turn instruction on
  /// demand — useful if he missed something, or if he's a blind or
  /// low-vision user relying entirely on voice and never looked at the
  /// screen text at all. This is the one manual control on an otherwise
  /// hands-free screen, and it's why it carries an explicit Semantics
  /// label rather than relying on the icon alone.
  Future<void> _repeatAloud() async {
    final messages = <String>[
      for (final advisory in _advisories)
        if (advisory.severity != AdvisorySeverity.info) advisory.message,
      if (_route != null && _currentStepIndex < _route!.steps.length)
        _route!.steps[_currentStepIndex].instruction,
    ];
    if (messages.isEmpty) {
      await _speak(
        'No warnings right now. Keep heading toward the destination.',
      );
      return;
    }
    await _tts.stop();
    for (final message in messages) {
      await _tts.speak(message);
    }
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

  /// He can back out of a delivery he can't complete — a puncture, a
  /// wrong address, anything. Confirmed first so it can't happen with a
  /// stray tap; cancelling clears his live-location marker too, and the
  /// order simply disappears from his list (streamAssignedOrders already
  /// filters out cancelled orders) so the admin can hand it to someone
  /// else.
  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this delivery?'),
        content: Text(
          'This will cancel the order to ${widget.order.deliveryLocation.name}. '
          'The admin will need to reassign it to someone else.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep delivering'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await OrderService.cancelOrder(widget.order.id);
      _clearMyLocation();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
        setState(() => _isCancelling = false);
      }
    }
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
      // A screen reader announces this button's label even though it's
      // icon-only — the one manual control on an otherwise hands-free,
      // voice-guided screen, meant for anyone who missed an instruction
      // or is navigating entirely by voice.
      floatingActionButton: FloatingActionButton(
        onPressed: _repeatAloud,
        backgroundColor: Colors.teal,
        tooltip: 'Repeat directions and warnings aloud',
        child: const Icon(Icons.replay, color: Colors.white),
      ),
      body: Column(
        children: [
          // The map is the dominant element now, same as a real
          // navigation app — everything else lives in a compact panel
          // underneath instead of pushing the map down the screen.
          Expanded(
            child: current == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _error == null
                                ? Icons.location_searching
                                : Icons.location_off,
                            size: 40,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error == null
                                ? 'Waiting for your location before the map can show...'
                                : 'Could not get your location:\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
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

          // Everything below the map: advisories, current instruction,
          // distance/time, and Cancel — the "bottom sheet" a real Maps
          // app would show.
          if (_advisories.isNotEmpty && current != null)
            _AdvisoryPanel(advisories: _advisories),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentInstruction != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
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
                          ),
                        ] else if (_isLoadingRoute) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Getting turn-by-turn directions...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        Semantics(
                          liveRegion: true,
                          child: Row(
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
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isCancelling ? null : _confirmCancel,
                            icon: _isCancelling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.close, color: Colors.white),
                            label: Text(
                              _isCancelling
                                  ? 'Cancelling...'
                                  : 'Cancel this delivery',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryPanel extends StatelessWidget {
  final List<AdvisoryMessage> advisories;
  const _AdvisoryPanel({required this.advisories});

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
    final sorted = List.of(advisories)
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
