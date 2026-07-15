import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../app/theme.dart';
import '../models/location.dart';
import 'route_optimizer_service.dart';

/// Converts our own [Location]/[RoutePlan] types into the Marker/Polyline
/// widgets flutter_map needs. Same job as before when this used
/// google_maps_flutter — swapped to OpenStreetMap tiles via flutter_map
/// since that needs no API key and no billing account at all, which
/// matters a lot more for a student project than prettier tiles do.
class MapsService {
  static ll.LatLng toLatLng(Location location) {
    return ll.LatLng(location.latitude, location.longitude);
  }

  static const List<Color> _windowColors = [
    Color(0xFF1B5E20), // primary green
    Color(0xFFEF6C00), // accent orange
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFFC62828), // red
  ];

  static List<Marker> buildMarkers(RoutePlan plan, Location vendorStart) {
    final markers = <Marker>[
      Marker(
        point: toLatLng(vendorStart),
        width: 44,
        height: 44,
        child: const Icon(Icons.storefront, color: Colors.deepPurple, size: 34),
      ),
    ];

    var stopNumber = 1;
    for (final window in plan.windows) {
      for (final stop in window.stops) {
        final isAtRisk = stop.isAtRiskOfLateness;
        markers.add(
          Marker(
            point: toLatLng(stop.order.deliveryLocation),
            width: 40,
            height: 40,
            child: _NumberedPin(
              number: stopNumber,
              color: isAtRisk ? Colors.red : AppColors.primaryGreen,
            ),
          ),
        );
        stopNumber++;
      }
    }

    // Flagged hazards, so the vendor sees why the plan routed around
    // (or through, with extra time) a given spot.
    for (final hazard in plan.conditions.activeHazards) {
      markers.add(
        Marker(
          point: ll.LatLng(hazard.latitude, hazard.longitude),
          width: 34,
          height: 34,
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 28,
          ),
        ),
      );
    }

    return markers;
  }

  /// Straight-line path between consecutive stops per time-window — an
  /// honest visual of what's being optimized (matches the Haversine
  /// distance the optimizer itself uses), not a real turn-by-turn route.
  static List<Polyline> buildPolylines(RoutePlan plan, Location vendorStart) {
    final polylines = <Polyline>[];
    Location current = vendorStart;
    var windowIndex = 0;

    for (final window in plan.windows) {
      final points = <ll.LatLng>[toLatLng(current)];
      for (final stop in window.stops) {
        points.add(toLatLng(stop.order.deliveryLocation));
      }
      if (window.stops.isNotEmpty) {
        current = window.stops.last.order.deliveryLocation;
      }

      polylines.add(
        Polyline(
          points: points,
          color: _windowColors[windowIndex % _windowColors.length],
          strokeWidth: 4,
        ),
      );
      windowIndex++;
    }

    return polylines;
  }
}

class _NumberedPin extends StatelessWidget {
  final int number;
  final Color color;

  const _NumberedPin({required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4),
            ],
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
