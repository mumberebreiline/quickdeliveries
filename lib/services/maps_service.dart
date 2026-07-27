import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';
import 'route_optimizer_service.dart';

/// Converts our Location/RoutePlan types into Google Maps widgets — just
/// markers now. Route/polyline drawing used to live here too, but it
/// was removed from the one screen that used it (the admin's Route
/// Overview) since showing every batch's route simultaneously, each a
/// different color, criss-crossing a wide area, was cluttered rather
/// than useful for what's really just a planning overview. Real
/// turn-by-turn route drawing still happens where it actually matters —
/// the delivery guy's own tracking screen, via DirectionsService
/// directly.
class MapsService {
  static LatLng toLatLng(Location location) =>
      LatLng(location.latitude, location.longitude);

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
            infoWindow: InfoWindow(
              title: '$stopNumber. ${stop.order.deliveryLocation.name}',
            ),
          ),
        );
        stopNumber++;
      }
    }
    return markers;
  }
}
