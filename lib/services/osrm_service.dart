import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/location.dart';

/// A single, real, road-following route (used for the polyline drawn on
/// the map) — points trace actual streets/footpaths, not a straight line.
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

/// A full pairwise table of real road distances/durations between every
/// point given, fetched in ONE network call. This is what actually lets
/// OSRM data influence *decisions* (which stop to visit next) instead of
/// just drawing a prettier line — the 2-opt algorithm needs a cost
/// between any two stops, not just one fixed sequence, and a distance
/// matrix is exactly that.
class OsrmMatrix {
  final List<Location> points;
  final List<List<double>> _durationsSeconds;
  final List<List<double>> _distancesMeters;
  final Map<String, int> _indexByLocationId;

  OsrmMatrix({
    required this.points,
    required List<List<double>> durationsSeconds,
    required List<List<double>> distancesMeters,
  }) : _durationsSeconds = durationsSeconds,
       _distancesMeters = distancesMeters,
       _indexByLocationId = {
         for (var i = 0; i < points.length; i++) points[i].id: i,
       };

  /// Real road travel time between two known points, in minutes — or
  /// null if either point wasn't part of this matrix (e.g. a new order
  /// that arrived after the matrix was fetched).
  double? durationMinutes(Location from, Location to) {
    final i = _indexByLocationId[from.id];
    final j = _indexByLocationId[to.id];
    if (i == null || j == null) return null;
    final seconds = _durationsSeconds[i][j];
    return seconds / 60;
  }

  double? distanceKm(Location from, Location to) {
    final i = _indexByLocationId[from.id];
    final j = _indexByLocationId[to.id];
    if (i == null || j == null) return null;
    final meters = _distancesMeters[i][j];
    return meters / 1000;
  }
}

/// Uses OSRM's free public demo server — no API key, no billing account,
/// ever. Meant for light/demo traffic (this is exactly that: a handful of
/// campus buildings, a few times a day), not heavy production use; if
/// this app ever needs to scale up seriously, the standard next step is
/// self-hosting the OSRM backend (still free, just needs a server).
class OsrmService {
  static const _routeUrl = 'https://router.project-osrm.org/route/v1/driving/';
  static const _tableUrl = 'https://router.project-osrm.org/table/v1/driving/';

  Future<RoadRoute> getRoute(List<Location> stops) async {
    if (stops.length < 2) throw 'Need at least 2 points to build a route';

    final coordsParam = stops
        .map((s) => '${s.longitude},${s.latitude}')
        .join(';');
    final url = Uri.parse(
      '$_routeUrl$coordsParam?overview=full&geometries=geojson',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['code'] != 'Ok') throw 'OSRM error: ${data['code']}';

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final coordinates = route['geometry']['coordinates'] as List;

    return RoadRoute(
      points: coordinates
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList(),
      distanceKm: (route['distance'] as num) / 1000.0,
      durationMinutes: (route['duration'] as num) / 60.0,
    );
  }

  /// Fetches real road distance/duration between every pair of [points]
  /// in one call, via OSRM's Table service. Returns null (rather than
  /// throwing) on any failure — network issue, demo server rate-limit,
  /// fewer than 2 points — so callers can cleanly fall back to the
  /// straight-line estimate instead of crashing route planning over a
  /// free, best-effort public service having a bad moment.
  Future<OsrmMatrix?> getDistanceMatrix(List<Location> points) async {
    if (points.length < 2) return null;

    try {
      final coordsParam = points
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final url = Uri.parse(
        '$_tableUrl$coordsParam?annotations=distance,duration',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final durations = (data['durations'] as List)
          .map(
            (row) => (row as List).map((v) => (v as num).toDouble()).toList(),
          )
          .toList();
      final distances = (data['distances'] as List)
          .map(
            (row) => (row as List).map((v) => (v as num).toDouble()).toList(),
          )
          .toList();

      return OsrmMatrix(
        points: points,
        durationsSeconds: durations,
        distancesMeters: distances,
      );
    } catch (e) {
      debugPrint(
        'OSRM matrix lookup failed, falling back to straight-line estimate: $e',
      );
      return null;
    }
  }
}
