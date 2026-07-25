import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';

class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes; // now LIVE-TRAFFIC-AWARE, unlike OSRM
  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

/// Same interface as the old OsrmMatrix — this is what lets
/// route_optimizer_service.dart barely need to change at all.
class GoogleMatrix {
  final List<Location> points;
  final List<List<double>> _durationsSeconds;
  final List<List<double>> _distancesMeters;
  final Map<String, int> _indexByLocationId;

  GoogleMatrix({
    required this.points,
    required List<List<double>> durationsSeconds,
    required List<List<double>> distancesMeters,
  }) : _durationsSeconds = durationsSeconds,
       _distancesMeters = distancesMeters,
       _indexByLocationId = {
         for (var i = 0; i < points.length; i++) points[i].id: i,
       };

  double? durationMinutes(Location from, Location to) {
    final i = _indexByLocationId[from.id];
    final j = _indexByLocationId[to.id];
    if (i == null || j == null) return null;
    final seconds = _durationsSeconds[i][j];
    if (seconds.isNaN) return null;
    return seconds / 60;
  }

  double? distanceKm(Location from, Location to) {
    final i = _indexByLocationId[from.id];
    final j = _indexByLocationId[to.id];
    if (i == null || j == null) return null;
    final meters = _distancesMeters[i][j];
    if (meters.isNaN) return null;
    return meters / 1000;
  }
}

/// Talks to Google's Directions + Distance Matrix APIs, both with
/// departure_time=now — this is what actually brings LIVE traffic into
/// the route, unlike OSRM's static-only road network.
class DirectionsService {
  // Passed in at run time, same pattern as before:
  // flutter run --dart-define=MAPS_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY');

  Future<RoadRoute> getRoute(List<Location> stops) async {
    if (stops.length < 2) throw 'Need at least 2 points to build a route';

    final origin = stops.first;
    final destination = stops.last;
    final waypoints = stops.sublist(1, stops.length - 1);
    final waypointsParam = waypoints.isEmpty
        ? ''
        : '&waypoints=${waypoints.map((w) => '${w.latitude},${w.longitude}').join('|')}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '$waypointsParam'
      '&departure_time=now'
      '&traffic_model=best_guess'
      '&key=$_apiKey',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') throw 'Directions API error: ${data['status']}';

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final legs = route['legs'] as List;

    double totalDistanceM = 0;
    double totalDurationS = 0;
    for (final leg in legs) {
      totalDistanceM += (leg['distance']['value'] as num);
      // duration_in_traffic is the LIVE number — falls back to plain
      // duration only if Google can't estimate traffic for some reason.
      final durationInTraffic = leg['duration_in_traffic'];
      totalDurationS += ((durationInTraffic ?? leg['duration'])['value'] as num);
    }

    return RoadRoute(
      points: _decodePolyline(route['overview_polyline']['points'] as String),
      distanceKm: totalDistanceM / 1000.0,
      durationMinutes: totalDurationS / 60.0,
    );
  }

  Future<GoogleMatrix?> getDistanceMatrix(List<Location> points) async {
    if (points.length < 2) return null;
    try {
      final coords = points.map((p) => '${p.latitude},${p.longitude}').join('|');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=$coords&destinations=$coords'
        '&departure_time=now'
        '&traffic_model=best_guess'
        '&key=$_apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final rows = data['rows'] as List;
      final n = points.length;
      final durations = List.generate(n, (_) => List<double>.filled(n, double.nan));
      final distances = List.generate(n, (_) => List<double>.filled(n, double.nan));

      for (var i = 0; i < rows.length; i++) {
        final elements = (rows[i] as Map<String, dynamic>)['elements'] as List;
        for (var j = 0; j < elements.length; j++) {
          final el = elements[j] as Map<String, dynamic>;
          if (el['status'] != 'OK') continue;
          final durationInTraffic = el['duration_in_traffic'];
          durations[i][j] = ((durationInTraffic ?? el['duration'])['value'] as num).toDouble();
          distances[i][j] = (el['distance']['value'] as num).toDouble();
        }
      }

      return GoogleMatrix(points: points, durationsSeconds: durations, distancesMeters: distances);
    } catch (e) {
      debugPrint('Google Distance Matrix lookup failed, falling back to straight-line estimate: $e');
      return null;
    }
  }

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