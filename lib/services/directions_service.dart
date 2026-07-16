import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';
import '../models/route_alternative.dart';

/// Wraps the Google Directions API. This is where live-traffic knowledge
/// actually comes from — we don't calculate or guess it ourselves, Google's
/// servers already aggregate real-time data across millions of devices;
/// we just ask for it.
class DirectionsService {
  // Passed in at build/run time with:
  //   flutter run --dart-define=MAPS_API_KEY=your_key_here
  // Never hardcoded here — see the Google Maps setup notes for why.
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY');

  Future<List<RouteAlternative>> getRouteOptions({
    required Location origin,
    required Location destination,
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&alternatives=true'          // ask for more than one option
      '&departure_time=now'         // required for live traffic data
      '&traffic_model=best_guess'
      '&key=$_apiKey',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw 'Directions API error: ${data['status']}';
    }

    final routes = data['routes'] as List;
    return routes.map((route) {
      final leg = (route['legs'] as List).first;

      return RouteAlternative(
        summary: route['summary'] as String? ?? 'Route',
        distanceKm: (leg['distance']['value'] as int) / 1000.0,
        // duration_in_traffic only appears when departure_time is set —
        // falls back to plain duration if Google can't estimate traffic.
        durationInTrafficMinutes:
            ((leg['duration_in_traffic'] ?? leg['duration'])['value'] as int) ~/ 60,
        durationTypicalMinutes: (leg['duration']['value'] as int) ~/ 60,
        polylinePoints: _decodePolyline(route['overview_polyline']['points'] as String),
      );
    }).toList();
  }

  /// Google encodes the route path as a compact string, not raw
  /// coordinates — this unpacks it into actual lat/lng points we can draw.
  /// This is Google's own polyline encoding spec, required by every
  /// Directions API consumer, not something specific to this app.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int shift = 0, result = 0, byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}