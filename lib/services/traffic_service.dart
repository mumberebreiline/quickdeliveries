import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location.dart';

/// Optional, free-tier-unfriendly (needs Google billing) — deliberately
/// left dormant by default. Uniform multiplier only refines ETA accuracy,
/// not stop ordering, so the app works fully without it.
class TrafficService {
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  Future<double> getTrafficMultiplier({
    required Location origin,
    required List<Location> destinations,
  }) async {
    if (_apiKey == 'YOUR_GOOGLE_MAPS_API_KEY' || destinations.isEmpty) {
      return 1.0;
    }
    try {
      final destinationParam = destinations
          .map((d) => '${d.latitude},${d.longitude}')
          .join('|');
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${origin.latitude},${origin.longitude}'
        '&destinations=$destinationParam'
        '&departure_time=now&traffic_model=best_guess&mode=driving&key=$_apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return 1.0;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = data['rows'] as List<dynamic>?;
      if (rows == null || rows.isEmpty) return 1.0;
      final elements =
          (rows.first as Map<String, dynamic>)['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) return 1.0;

      double totalRatio = 0;
      int count = 0;
      for (final element in elements) {
        final e = element as Map<String, dynamic>;
        if (e['status'] != 'OK') continue;
        final normalSeconds = (e['duration']?['value'] as num?)?.toDouble();
        final trafficSeconds = (e['duration_in_traffic']?['value'] as num?)
            ?.toDouble();
        if (normalSeconds != null &&
            trafficSeconds != null &&
            normalSeconds > 0) {
          totalRatio += trafficSeconds / normalSeconds;
          count++;
        }
      }
      if (count == 0) return 1.0;
      return totalRatio / count;
    } catch (e) {
      debugPrint('Traffic lookup failed, assuming normal conditions: $e');
      return 1.0;
    }
  }
}
