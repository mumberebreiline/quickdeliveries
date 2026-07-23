import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../models/location.dart';

class LocationService {
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      // v5+ of the geocoding package requires an instance — placemarkFromCoordinates
      // is no longer a plain top-level function.
      final geocodingService = geocoding.Geocoding();
      final placemarks = await geocodingService.placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return "Current Location";
      }

      final place = placemarks.first;

      final parts = <String>{};

      void add(String? value) {
        if (value != null && value.trim().isNotEmpty) {
          parts.add(value.trim());
        }
      }

      add(place.name);
      add(place.street);
      add(place.subLocality);
      add(place.locality);
      add(place.administrativeArea);
      add(place.country);

      if (parts.isEmpty) {
        return "Current Location";
      }

      return parts.join(", ");
    } catch (e) {
      print("Reverse geocoding error: $e");
      return "Current Location";
    }
  }

  Future<Location> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw "Please enable Location Services.";
    }

    final hasPermission = await ensurePermission();

    if (!hasPermission) {
      throw "Location permission denied.";
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final address = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );

    return Location(
      id: "current_location",
      name: address,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Stream<Location> streamLocation() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).asyncMap((position) async {
      final address = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      return Location(
        id: "current_location",
        name: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }
}