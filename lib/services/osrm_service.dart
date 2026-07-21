import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/location.dart';

class RoadRoute {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RoadRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class OsrmService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving/';

  Future<RoadRoute> getRoute(List<Location> stops) async {
    if (stops.length < 2) throw 'Need at least 2 points to build a route';

    final coordsParam = stops.map((s) => '${s.longitude},${s.latitude}').join(';');
    final url = Uri.parse('$_baseUrl$coordsParam?overview=full&geometries=geojson');

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['code'] != 'Ok') throw 'OSRM error: ${data['code']}';

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final coordinates = route['geometry']['coordinates'] as List;

    return RoadRoute(
      points: coordinates.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList(),
      distanceKm: (route['distance'] as num) / 1000.0,
      durationMinutes: (route['duration'] as num) / 60.0,
    );
  }
}