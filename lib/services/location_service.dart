import 'package:geolocator/geolocator.dart';
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

  Stream<Location> streamLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
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
