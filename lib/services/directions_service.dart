import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';

/// One turn-by-turn instruction — "Turn left onto University Road," how
/// far into the route it kicks in, and where it starts (so the tracking
/// screen knows when the delivery guy has actually reached this point
/// and it's time to speak the *next* instruction instead).
class NavigationStep {
  final String instruction;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  const NavigationStep({
    required this.instruction,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });
}

class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes; // now LIVE-TRAFFIC-AWARE, unlike OSRM
  final List<NavigationStep> steps;
  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    this.steps = const [],
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
    required this._durationsSeconds,
    required this._distancesMeters,
  }) : _indexByLocationId = {
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
  // Passed in at run time via `flutter run --dart-define=MAPS_API_KEY=...`
  // — but that flag is easy to forget on an ordinary `flutter run`, and
  // when it's missing this silently becomes an empty string, which is
  // exactly what caused every Directions/Distance Matrix call to fail
  // with a URL ending in "&key=" and nothing after it. Falling back to
  // the same key already sitting in web/index.html's script tag means
  // this works without remembering the flag — for a web app that key is
  // visible in the page source either way, so this doesn't expose
  // anything that wasn't already exposed. Restrict this key to your own
  // domain/package name in Google Cloud Console → Credentials, so it
  // can't be reused elsewhere even though it's publicly visible.
  static const String _apiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyAkXd_6STGjF49bJARe7eyPvohqw7m89bo',
  );

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
    final steps = <NavigationStep>[];
    for (final leg in legs) {
      totalDistanceM += (leg['distance']['value'] as num);
      // duration_in_traffic is the LIVE number — falls back to plain
      // duration only if Google can't estimate traffic for some reason.
      final durationInTraffic = leg['duration_in_traffic'];
      totalDurationS +=
          ((durationInTraffic ?? leg['duration'])['value'] as num);

      for (final rawStep in (leg['steps'] as List)) {
        final step = rawStep as Map<String, dynamic>;
        final startLocation = step['start_location'] as Map<String, dynamic>;
        steps.add(
          NavigationStep(
            instruction: _stripHtml(step['html_instructions'] as String? ?? ''),
            latitude: (startLocation['lat'] as num).toDouble(),
            longitude: (startLocation['lng'] as num).toDouble(),
            distanceMeters: (step['distance']['value'] as num).toDouble(),
          ),
        );
      }
    }

    return RoadRoute(
      points: _decodePolyline(route['overview_polyline']['points'] as String),
      distanceKm: totalDistanceM / 1000.0,
      durationMinutes: totalDurationS / 60.0,
      steps: steps,
    );
  }

  /// Google's step instructions come as HTML ("Turn <b>left</b> onto...")
  /// — fine for on-screen text, but a text-to-speech engine would read
  /// the tags aloud literally. Strip them before speaking or displaying.
  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Future<GoogleMatrix?> getDistanceMatrix(List<Location> points) async {
    if (points.length < 2) return null;
    try {
      final coords = points
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');
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
      final durations = List.generate(
        n,
        (_) => List<double>.filled(n, double.nan),
      );
      final distances = List.generate(
        n,
        (_) => List<double>.filled(n, double.nan),
      );

      for (var i = 0; i < rows.length; i++) {
        final elements = (rows[i] as Map<String, dynamic>)['elements'] as List;
        for (var j = 0; j < elements.length; j++) {
          final el = elements[j] as Map<String, dynamic>;
          if (el['status'] != 'OK') continue;
          final durationInTraffic = el['duration_in_traffic'];
          durations[i][j] =
              ((durationInTraffic ?? el['duration'])['value'] as num)
                  .toDouble();
          distances[i][j] = (el['distance']['value'] as num).toDouble();
        }
      }

      return GoogleMatrix(
        points: points,
        durationsSeconds: durations,
        distancesMeters: distances,
      );
    } catch (e) {
      debugPrint(
        'Google Distance Matrix lookup failed, falling back to straight-line estimate: $e',
      );
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
