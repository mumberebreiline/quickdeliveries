import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position> getCurrentLocation() async {
    // Is GPS even switched on at the OS level?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please turn on location.';
    }

    // What's our current permission status?
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Not asked yet — this line is what triggers the system popup.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission was denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // User ticked "don't ask again" — requestPermission() won't even
      // show a popup now, so we have to tell them to fix it manually.
      throw 'Location permission is permanently denied. Enable it in settings.';
    }

    // All checks passed — now actually read the coordinates.
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}