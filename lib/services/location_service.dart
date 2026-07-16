import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

/// Wraps geolocator so the rest of the app deals with our own [Location]
/// type, not a raw GPS Position.
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

  /// The vendor's current GPS position, as a [Location] the route optimizer
  /// can use as the starting point of the delivery run.
  Future<Location?> getCurrentLocation() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;


  final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return Location(
      id: 'vendor_current',
      name: 'Current Location',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Live stream of the vendor's position, useful for showing her moving
  /// marker on the route map while she's out delivering.
  Stream<Location> streamLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // metres before a new update fires
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => Location(
        id: 'vendor_current',
        name: 'Current Location',
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }
}
