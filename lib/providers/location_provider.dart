import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';

/// Tracks where the vendor currently is, for the route optimizer's
/// starting point. Falls back to the fixed vendor base location if GPS
/// isn't available yet.
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  bool _isTracking = false;

  LocationProvider({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

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
