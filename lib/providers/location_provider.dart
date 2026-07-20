import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';

/// Tracks where the vendor currently is. The route optimizer needs a
/// starting point for every delivery run — this provider supplies it,
/// falling back to the fixed [CampusLocations.vendorBase] if GPS isn't
/// available yet (e.g. permission not granted, or running on an emulator).
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  bool _isTracking = false;

  LocationProvider({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  /// Always returns something usable, even before GPS resolves.
  Location get currentLocation =>
      _currentLocation ?? CampusLocations.vendorBase;

  bool get isTracking => _isTracking;

  Future<void> refreshOnce() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      _currentLocation = location;
      notifyListeners();
    }
  }

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _locationSub = _locationService.streamLocation().listen((location) {
      _currentLocation = location;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }
}
