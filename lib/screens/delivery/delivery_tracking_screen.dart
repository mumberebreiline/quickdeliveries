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
/// a real navigation app: the map fills almost the whole screen, with a
/// compact bottom panel for distance/time/cancel. Given several assigned
/// stops at once, this works out the most *time-efficient* order to hit
/// them in (real, traffic-aware minutes from Google — deliberately not
/// always the shortest distance), then guides him through each one in
/// turn automatically: arriving at one stop marks it delivered and
/// immediately starts guiding to the next, with no need to back out to
/// the list and tap Start again in between.
///
/// Nothing here is tied to a specific person — whichever delivery guy
/// account is logged in gets guided through whichever orders they were
/// assigned, however many delivery guys the admin has set up.
class DeliveryTrackingScreen extends StatefulWidget {
  final List<FoodOrder> orders;

  const DeliveryTrackingScreen({super.key, required this.orders});

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
  final _routeOptimizer = RouteOptimizerService();
  final FlutterTts _tts = FlutterTts();

  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  List<FoodOrder>? _sequencedStops; // null until the optimal order is computed
  int _currentStopIndex = 0;
  RoadRoute? _route; // route for the CURRENT leg only
  double? _speedKmPerMinute;
  int _currentInstructionStepIndex = 0;
  String? _error;
  bool _isLoadingRoute = true;
  bool _isCancelling = false;
  bool _allDone = false;

  List<AdvisoryMessage> _advisories = [];

  FoodOrder? get _currentOrder =>
      _sequencedStops == null || _currentStopIndex >= _sequencedStops!.length
      ? null
      : _sequencedStops![_currentStopIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _begin();
  }

  Future<void> _begin() async {
    try {
      final initial = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _currentLocation = initial);
      _pushMyLocation(initial);

      // Advisories are for the whole trip, spoken once up front — not
      // re-fetched or re-announced between every individual stop.
      await _loadAdvisories(initial);

      // The one genuinely non-trivial piece of logic here: work out the
      // fastest order to visit every assigned stop in, using real
      // traffic-aware travel times, not just distance.
      final sequenced = await _routeOptimizer.sequenceStopsForDeliveryGuy(
        widget.orders,
        startLocation: initial,
      );
      if (!mounted) return;
      setState(() => _sequencedStops = sequenced);

      await _beginLegToCurrentStop(initial);
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

    final worthSpeaking = advisories.where(
      (a) => a.severity != AdvisorySeverity.info,
    );
    for (final advisory in worthSpeaking) {
      await _speak(advisory.message);
    }
  }

  /// Starts (or restarts) navigation for whichever stop is currently
  /// active — called once at the beginning, and again automatically
  /// every time a stop is completed and there's another one to go.
  Future<void> _beginLegToCurrentStop(Location from) async {
    final order = _currentOrder;
    if (order == null) return;

    if (order.status != OrderStatus.outForDelivery) {
      await OrderService.updateStatus(order.id, OrderStatus.outForDelivery);
    }

    setState(() {
      _route = null;
      _currentInstructionStepIndex = 0;
      _isLoadingRoute = true;
    });

    try {
      final route = await _directionsService.getRoute([
        from,
        order.deliveryLocation,
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
      debugPrint('Directions fetch failed, falling back to straight line: $e');
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _speak(String instruction) async {
    await _tts.stop();
    await _tts.speak(instruction);
  }

  /// Lets him re-hear the current advisories and turn instruction on
  /// demand — the one manual control on an otherwise hands-free screen.
  Future<void> _repeatAloud() async {
    final messages = <String>[
      for (final advisory in _advisories)
        if (advisory.severity != AdvisorySeverity.info) advisory.message,
      if (_route != null && _currentInstructionStepIndex < _route!.steps.length)
        _route!.steps[_currentInstructionStepIndex].instruction,
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
    if (_allDone) return;
    final order = _currentOrder;
    if (order == null) return;

    // Advance through spoken turn-by-turn steps for the current leg.
    final route = _route;
    if (route != null && _currentInstructionStepIndex < route.steps.length) {
      final nextStep = route.steps[_currentInstructionStepIndex];
      final stepLocation = Location(
        id: 'step',
        name: 'step',
        latitude: nextStep.latitude,
        longitude: nextStep.longitude,
      );
      if (current.distanceToKm(stepLocation) <= _stepArrivalRadiusKm) {
        _currentInstructionStepIndex++;
        if (_currentInstructionStepIndex < route.steps.length) {
          setState(() {});
          _speak(route.steps[_currentInstructionStepIndex].instruction);
        }
      }
    }

    final distanceKm = current.distanceToKm(order.deliveryLocation);
    if (distanceKm <= _arrivalRadiusKm) {
      _handleArrivalAtCurrentStop(current);
    }
  }

  /// The moment he reaches a stop, it's marked delivered automatically —
  /// and if there's another stop left, navigation continues straight to
  /// it, with no button to press in between. Only once every assigned
  /// stop is done does this actually stop and hand control back.
  Future<void> _handleArrivalAtCurrentStop(Location current) async {
    final order = _currentOrder;
    if (order == null) return;

    await OrderService.updateStatus(order.id, OrderStatus.delivered);

    final isLastStop = _currentStopIndex >= _sequencedStops!.length - 1;

    if (isLastStop) {
      _allDone = true;
      _locationSub?.cancel();
      _clearMyLocation();
      _speak('All deliveries complete. Great work.');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('All done!'),
            content: const Text(
              'Every stop on this run has been delivered. Nice work.',
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
      return;
    }

    // More stops to go — announce and continue immediately, no separate
    // button press needed.
    _speak('Stop delivered. Heading to the next one.');
    setState(() => _currentStopIndex++);
    await _beginLegToCurrentStop(current);
  }

  void _clearMyLocation() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userService.clearMyLocation(uid);
  }

  /// Cancels only the CURRENT stop — not the whole run. If there are
  /// more stops left, navigation continues to the next one exactly as
  /// if this one had been delivered, just without marking it complete.
  Future<void> _confirmCancelCurrentStop() async {
    final order = _currentOrder;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this stop?'),
        content: Text(
          'This cancels the order to ${order.deliveryLocation.name}. '
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
            child: const Text('Cancel this stop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await OrderService.cancelOrder(order.id);

      final isLastStop = _currentStopIndex >= _sequencedStops!.length - 1;
      if (isLastStop) {
        _locationSub?.cancel();
        _clearMyLocation();
        if (mounted) Navigator.pop(context);
        return;
      }

      final current = _currentLocation;
      setState(() {
        _currentStopIndex++;
        _isCancelling = false;
      });
      if (current != null) await _beginLegToCurrentStop(current);
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
    if (!_allDone) _clearMyLocation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentLocation;
    final order = _currentOrder;
    final sequence = _sequencedStops;

    if (sequence == null || order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Getting ready...'),
          backgroundColor: Colors.teal,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error == null) ...[
                  const CircularProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 12),
                  const Text(
                    'Working out the fastest order to visit your stops...',
                  ),
                ] else
                  Text(_error!, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final destination = order.deliveryLocation;
    final distanceKm = current?.distanceToKm(destination);
    final etaMinutes = distanceKm == null
        ? null
        : (_speedKmPerMinute != null && _speedKmPerMinute! > 0)
        ? distanceKm / _speedKmPerMinute!
        : (distanceKm / AppConfig.assumedSpeedKmh) * 60;

    final currentInstruction =
        (_route != null && _currentInstructionStepIndex < _route!.steps.length)
        ? _route!.steps[_currentInstructionStepIndex].instruction
        : null;

    // Remaining stops (current one onward) get numbered pins, each
    // carrying that order's details so tapping a pin actually tells him
    // something — not just a name.
    final remainingStops = sequence.sublist(_currentStopIndex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Stop ${_currentStopIndex + 1} of ${sequence.length} — ${destination.name}',
        ),
        backgroundColor: Colors.teal,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _repeatAloud,
        backgroundColor: Colors.teal,
        tooltip: 'Repeat directions and warnings aloud',
        child: const Icon(Icons.replay, color: Colors.white),
      ),
      body: Column(
        children: [
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
                      for (var i = 0; i < remainingStops.length; i++)
                        Marker(
                          markerId: MarkerId('stop_${remainingStops[i].id}'),
                          position: LatLng(
                            remainingStops[i].deliveryLocation.latitude,
                            remainingStops[i].deliveryLocation.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            i == 0
                                ? BitmapDescriptor.hueRed
                                : BitmapDescriptor.hueOrange,
                          ),
                          infoWindow: _infoWindowFor(remainingStops[i]),
                        ),
                    },
                  ),
          ),
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
                              if (sequence.length > 1)
                                _StatColumn(
                                  label: 'Stops left',
                                  value:
                                      '${sequence.length - _currentStopIndex}',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isCancelling
                                ? null
                                : _confirmCancelCurrentStop,
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
                                  : 'Cancel this stop',
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

  /// Order details on the pin itself, as requested — name, phone, and
  /// what's in the order, so tapping a marker actually tells him
  /// something useful instead of just a building name.
  InfoWindow _infoWindowFor(FoodOrder order) {
    final itemsSummary = order.items
        .map((i) => '${i.quantity}x ${i.name}')
        .join(', ');
    return InfoWindow(
      title:
          '${order.customerName.isEmpty ? "Customer" : order.customerName}'
          '${order.customerPhone.isEmpty ? "" : " • ${order.customerPhone}"}',
      snippet: itemsSummary.isEmpty
          ? order.deliveryLocation.name
          : itemsSummary,
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
