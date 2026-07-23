import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/location.dart';
import 'route_optimizer_service.dart';

/// Converts our Location/RoutePlan types into flutter_map widgets.
/// Uses OpenStreetMap tiles — free, no API key, no billing account,
/// unlike Google Maps. This is the only file that bridges our route
/// logic to the map SDK; the optimizer itself has no map dependency.
class MapsService {
  static ll.LatLng toLatLng(Location location) =>
      ll.LatLng(location.latitude, location.longitude);

  static const List<Color> _windowColors = [
    Color(0xFF1B5E20),
    Color(0xFFEF6C00),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
  ];

  static Color colorForWindow(int index) =>
      _windowColors[index % _windowColors.length];

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
              color: isAtRisk ? Colors.red : Colors.green,
            ),
          ),
        );
        stopNumber++;
      }
    }

    return markers;
  }

  static List<Polyline> buildPolylines(
    RoutePlan plan,
    Location vendorStart, {
    Set<int> skipWindows = const {},
  }) {
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
      if (!skipWindows.contains(windowIndex)) {
        polylines.add(
          Polyline(
            points: points,
            color: colorForWindow(windowIndex),
            strokeWidth: 4,
          ),
        );
      }
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
    return Container(
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
    );
  }
}
