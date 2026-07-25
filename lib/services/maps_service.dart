import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';
import 'route_optimizer_service.dart';

/// Converts our Location/RoutePlan types into Google Maps widgets.
class MapsService {
  static LatLng toLatLng(Location location) =>
      LatLng(location.latitude, location.longitude);

  static const List<Color> _windowColors = [
    Color(0xFF1B5E20),
    Color(0xFFEF6C00),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
  ];

  static Color colorForWindow(int index) =>
      _windowColors[index % _windowColors.length];

  static Set<Marker> buildMarkers(RoutePlan plan, Location vendorStart) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('vendor'),
        position: toLatLng(vendorStart),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'You'),
      ),
    };

    var stopNumber = 1;
    for (final window in plan.windows) {
      for (final stop in window.stops) {
        final isAtRisk = stop.isAtRiskOfLateness;
        markers.add(
          Marker(
            markerId: MarkerId('stop_$stopNumber'),
            position: toLatLng(stop.order.deliveryLocation),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isAtRisk ? BitmapDescriptor.hueRed : BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(title: '$stopNumber. ${stop.order.deliveryLocation.name}'),
          ),
        );
        stopNumber++;
      }
    }
    return markers;
  }

  static Set<Polyline> buildPolylines(
    RoutePlan plan,
    Location vendorStart, {
    Set<int> skipWindows = const {},
  }) {
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
      if (!skipWindows.contains(windowIndex)) {
        polylines.add(
          Polyline(
            polylineId: PolylineId('window_$windowIndex'),
            points: points,
            color: colorForWindow(windowIndex),
            width: 4,
          ),
        );
      }
      windowIndex++;
    }
    return polylines;
  }
}