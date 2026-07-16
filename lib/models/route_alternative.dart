import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One possible path between two points, as returned by Google Directions.
/// Google typically returns 1-3 of these per request when alternatives=true
/// — this is what lets the vendor pick between options, same as the
/// route cards you see in the real Google Maps app.
class RouteAlternative {
  final String summary; // e.g. "via University Rd" — Google generates this
  final double distanceKm;
  final int durationInTrafficMinutes; // live-traffic-aware ETA
  final int durationTypicalMinutes; // ETA with no traffic, for comparison
  final List<LatLng> polylinePoints; // the actual road-following path

  const RouteAlternative({
    required this.summary,
    required this.distanceKm,
    required this.durationInTrafficMinutes,
    required this.durationTypicalMinutes,
    required this.polylinePoints,
  });

  /// How many extra minutes traffic is currently adding to this route.
  /// Positive = slower than usual (jam), ~0 = flowing normally.
  int get trafficDelayMinutes => durationInTrafficMinutes - durationTypicalMinutes;
}