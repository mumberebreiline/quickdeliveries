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
class LiveFleetScreen extends StatefulWidget {
  const LiveFleetScreen({super.key});

  @override
  State<LiveFleetScreen> createState() => _LiveFleetScreenState();
}

class _LiveFleetScreenState extends State<LiveFleetScreen> {
  static const _staleAfter = Duration(minutes: 10);

  final _userService = UserService();
  GoogleMapController? _mapController;

  // Tracks which uids we've already fitted the camera to, so it doesn't
  // keep yanking the admin's view back to "fit everyone" every single
  // time a position updates by a few metres - only when the actual SET
  // of active delivery guys changes (someone starts or finishes a
  // delivery).
  Set<String> _lastFittedUids = {};

  void _fitCameraToActiveGuys(List<AppUserProfile> active) {
    final controller = _mapController;
    if (controller == null || active.isEmpty) return;

    final currentUids = active.map((g) => g.uid).toSet();
    if (currentUids.length == _lastFittedUids.length &&
        currentUids.every(_lastFittedUids.contains)) {
      return; // same set of active guys as last time - don't re-fit
    }
    _lastFittedUids = currentUids;

    if (active.length == 1) {
      // Only one active guy - a bounds object with zero area isn't
      // meaningful, so just centre on him directly instead.
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(active.first.currentLatitude!, active.first.currentLongitude!),
          14,
        ),
      );
      return;
    }

    // This is the actual fix - instead of centring on whichever guy
    // happens to be first in the list at a fixed zoom (which left
    // everyone else's pin sitting outside the visible map), compute a
    // bounding box that contains every active guy's position and ask
    // the map to zoom/pan to fit all of them on screen at once.
    var minLat = active.first.currentLatitude!;
    var maxLat = active.first.currentLatitude!;
    var minLng = active.first.currentLongitude!;
    var maxLng = active.first.currentLongitude!;
    for (final guy in active) {
      minLat = guy.currentLatitude! < minLat ? guy.currentLatitude! : minLat;
      maxLat = guy.currentLatitude! > maxLat ? guy.currentLatitude! : maxLat;
      minLng = guy.currentLongitude! < minLng ? guy.currentLongitude! : minLng;
      maxLng = guy.currentLongitude! > maxLng ? guy.currentLongitude! : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // google_maps_flutter can throw if newLatLngBounds is called before
    // the map widget has actually finished laying out (a real, known
    // timing issue right when onMapCreated first fires) - retrying
    // after a short delay, wrapped in a try/catch, is the standard
    // workaround rather than letting that failure silently mean
    // "only the first pin visible."
    try {
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Fleet'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<List<AppUserProfile>>(
        stream: _userService.streamDeliveryGuys(),
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

          // Scheduled after the frame, not called directly during
          // build - moving the camera can trigger further rebuilds,
          // which build() itself shouldn't kick off synchronously.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _fitCameraToActiveGuys(active),
          );

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
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _fitCameraToActiveGuys(active);
                        },
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
                color: Colors.deepPurple.withValues(alpha: 0.06),
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
