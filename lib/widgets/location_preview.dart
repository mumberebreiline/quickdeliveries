import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/location.dart';

/// A small "what does this spot actually look like" snapshot — real
/// aerial/satellite imagery zoomed right into the exact captured GPS
/// point, not a schematic map. This is the closest thing to an actual
/// photo of a delivery location that's achievable for free: Google
/// Street View would need paid billing, and even then almost certainly
/// has no coverage of footpaths between halls — only public roads.
/// Satellite imagery covers everywhere, no key, no billing account.
///
/// Uses Esri's public World Imagery tile service — same free-tier
/// spirit as the OpenStreetMap tiles already used for the main map:
/// no signup, but meant for light/demo use, not heavy production
/// traffic.
class LocationPreview extends StatelessWidget {
  final Location location;
  final double size;

  const LocationPreview({super.key, required this.location, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final center = ll.LatLng(location.latitude, location.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: IgnorePointer(
          // This is a snapshot, not an interactive map — no pinch-zoom
          // or drag inside a list of these.
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.example.quickdeliveries',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 20,
                    height: 20,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
