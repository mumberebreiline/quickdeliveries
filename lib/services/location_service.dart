import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../models/location.dart';

class LocationService {
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Turns raw lat/lng into a human-readable place name, e.g.
  /// "Lumumba Hall, Makerere". Falls back to a plain coordinate string
  /// if geocoding fails — never throws, since a missing NAME shouldn't
  /// block placing an order when we still have valid coordinates.
  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      // v5+ of the geocoding package requires an instance — this is the
      // new required pattern, not something specific to our app.
      final geocodingService = geocoding.Geocoding();
      final placemarks = await geocodingService.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return 'Current location';

      final place = placemarks.first;
      // Build the readable name from whichever parts are actually
      // available — not every placemark has all fields filled in.
      final parts = [
        place.name,
        place.subLocality,
        place.locality,
      ].where((p) => p != null && p.isNotEmpty).toSet(); // toSet() drops duplicates
      // e.g. place.name and place.subLocality are sometimes identical

      return parts.isEmpty ? 'Current location' : parts.join(', ');
    } catch (_) {
      return 'Current location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
    }
  }

  /// Throws a specific, human-readable String on failure instead of
  /// silently returning null — so the UI can tell the user exactly
  /// what went wrong, rather than quietly showing a fake location.
  Future<Location> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are turned off. Please enable GPS.';
    }

    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      throw 'Location permission was denied. Please allow it to use your real location.';
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final placeName = await _reverseGeocode(position.latitude, position.longitude);

    return Location(
      id: 'vendor_current',
      name: placeName, // real place name now, not a hardcoded string
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Stream<Location> streamLocation() {
    const settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => Location(
        id: 'vendor_current',
        // NOT reverse-geocoded here — this stream fires continuously
        // while tracking, and reverse geocoding is a network call.
        // Doing it on every GPS update would hammer the geocoding
        // service and likely hit rate limits fast. A one-time fetch
        // via getCurrentLocation() is the right place for a real name;
        // continuous tracking just needs coordinates for route math.
        name: 'Current location',
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }
}