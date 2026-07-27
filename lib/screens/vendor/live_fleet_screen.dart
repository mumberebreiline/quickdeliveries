import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/app_user_profile.dart';
import '../../services/user_service.dart';

/// The admin's "watch over where the delivery guys are" screen — every
/// delivery guy who's currently out on a delivery shows up as a live
/// marker, updating as his own tracking screen reports new positions.
/// Someone who isn't currently delivering (no recent location) doesn't
/// show a marker at all, rather than a stale one sitting in the wrong
/// place forever.
class LiveFleetScreen extends StatelessWidget {
  const LiveFleetScreen({super.key});

  static const _staleAfter = Duration(minutes: 10);

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Fleet'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<List<AppUserProfile>>(
        stream: userService.streamDeliveryGuys(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final all = snapshot.data!;
          final active = all.where((guy) {
            if (guy.currentLatitude == null ||
                guy.currentLongitude == null ||
                guy.locationUpdatedAt == null) {
              return false;
            }
            return now.difference(guy.locationUpdatedAt!) <= _staleAfter;
          }).toList();
          final offline = all.length - active.length;

          return Column(
            children: [
              Expanded(
                child: active.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty
                                ? 'No delivery guy accounts exist yet.'
                                : 'Nobody is currently out on a delivery — '
                                      'markers only show up here while someone has '
                                      'an active delivery underway.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            active.first.currentLatitude!,
                            active.first.currentLongitude!,
                          ),
                          zoom: 13,
                        ),
                        markers: active
                            .map(
                              (guy) => Marker(
                                markerId: MarkerId(guy.uid),
                                position: LatLng(
                                  guy.currentLatitude!,
                                  guy.currentLongitude!,
                                ),
                                infoWindow: InfoWindow(
                                  title: guy.name ?? 'Delivery guy',
                                  snippet:
                                      'Last updated ${_minutesAgo(guy.locationUpdatedAt!)}',
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure,
                                ),
                              ),
                            )
                            .toSet(),
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.deepPurple.withOpacity(0.06),
                child: Text(
                  '${active.length} out delivering now'
                  '${offline > 0 ? ' • $offline not currently active' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _minutesAgo(DateTime time) {
    final minutes = DateTime.now().difference(time).inMinutes;
    if (minutes < 1) return 'just now';
    return '$minutes min ago';
  }
}
