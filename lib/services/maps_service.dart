import 'package:flutter/material.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';
import 'route_optimizer_service.dart';

/// Turns our own [Location]/[RoutePlan] types into the Marker/Polyline
/// objects google_maps_flutter needs. Keeping this conversion in one place
/// means the route optimizer stays completely independent of the Maps SDK
/// (it's plain Dart, easy to unit-test) — this is the only file that
/// bridges the two.
class MapsService {
  static LatLng toLatLng(Location location) {
    return LatLng(location.latitude, location.longitude);
  }

  /// A distinct colour per time-window, so the vendor can visually tell
  /// batches apart on the map (cycles if there are more windows than colours).
  static const List<Color> _windowColors = [
    Color(0xFF1B5E20), // primary green
    Color(0xFFEF6C00), // accent orange
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFFC62828), // red
  ];

  static Set<Marker> buildMarkers(RoutePlan plan, Location vendorStart) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('vendor_start'),
        position: toLatLng(vendorStart),
        infoWindow: InfoWindow(title: vendorStart.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    };

    var stopNumber = 1;
    for (final window in plan.windows) {
      for (final stop in window.stops) {
        markers.add(
          Marker(
            markerId: MarkerId(stop.order.id),
            position: toLatLng(stop.order.deliveryLocation),
            infoWindow: InfoWindow(
              title: '$stopNumber. ${stop.order.deliveryLocation.name}',
              snippet:
                  '${stop.order.customerName} — '
                  '${stop.isAtRiskOfLateness ? "at risk of lateness" : "on time"}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              stop.isAtRiskOfLateness
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueGreen,
            ),
          ),
        );
        stopNumber++;
      }
    }

    // Flagged hazards near the route, so the vendor sees *why* the plan
    // routed around (or through, with extra time) a given spot.
    for (final hazard in plan.conditions.activeHazards) {
      markers.add(
        Marker(
          markerId: MarkerId('hazard_${hazard.id}'),
          position: LatLng(hazard.latitude, hazard.longitude),
          infoWindow: InfoWindow(
            title: 'Reported hazard',
            snippet: hazard.description,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    return markers;
  }

  /// Straight-line path between consecutive stops for each time-window
  /// (matches the Haversine distance the optimizer already uses — this is
  /// an honest visual of what's being optimized, not a real driving route).
  /// Swap for Google Directions polylines later if turn-by-turn roads
  /// matter more than a quick visual.
  static Set<Polyline> buildPolylines(RoutePlan plan, Location vendorStart) {
    final polylines = <Polyline>{};
    Location current = vendorStart;
    var windowIndex = 0;

    for (final window in plan.windows) {
      final points = <LatLng>[toLatLng(current)];
      for (final stop in window.stops) {
        points.add(toLatLng(stop.order.deliveryLocation));
      }
      if (window.stops.isNotEmpty) {
        current = window.stops.last.order.deliveryLocation;
      }

      polylines.add(
        Polyline(
          polylineId: PolylineId('window_$windowIndex'),
          points: points,
          color: _windowColors[windowIndex % _windowColors.length],
          width: 4,
        ),
      );
      windowIndex++;
    }

    return polylines;
  }
}
