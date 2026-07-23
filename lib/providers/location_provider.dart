import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../services/location_service.dart';
import '../utils/constants.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  StreamSubscription<Location>? _locationSub;

  Location? _currentLocation;
  bool _isTracking = false;
  bool _isLocating = false;
  String? _error;

  LocationProvider({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  /// Still falls back to vendorBase so the rest of the app never crashes
  /// on a null location — but now _error tells you WHY it's a fallback,
  /// instead of that being invisible.
  Location get currentLocation => _currentLocation ?? CampusLocations.vendorBase;
  bool get isTracking => _isTracking;
  bool get isLocating => _isLocating;
  String? get error => _error;
  bool get hasRealLocation => _currentLocation != null;

  Future<void> refreshOnce() async {
    _isLocating = true;
    _error = null;
    notifyListeners();

    try {
      final location = await _locationService.getCurrentLocation();
      _currentLocation = location;
      _error = null;
    } catch (e) {
      _error = e.toString();
      // Deliberately NOT clearing _currentLocation here — if we had a
      // real fix before and this refresh just failed, keep showing the
      // last known-good position instead of snapping back to the fallback.
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _error = null;
    _locationSub = _locationService.streamLocation().listen(
      (location) {
        _currentLocation = location;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
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