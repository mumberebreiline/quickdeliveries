import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location.dart';

/// A small satellite snapshot of a delivery location.
class LocationPreview extends StatelessWidget {
  final Location location;
  final double size;

  const LocationPreview({super.key, required this.location, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final center = LatLng(location.latitude, location.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: IgnorePointer(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 19),
            mapType: MapType.satellite,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: false,
            markers: {
              Marker(markerId: const MarkerId('preview'), position: center),
            },
          ),
        ),
      ),
    );
  }
}