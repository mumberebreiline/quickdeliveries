import 'dart:math';

/// Represents a physical point on campus — a hall of residence, a lecture
/// block, the vendor's base/kitchen, etc. Anything that has a lat/lng and
/// can be a delivery destination or a starting point for a route.
class Location {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// Optional human-readable extra info, e.g. "Behind CTF1, Gate 2".
  final String? description;

  const Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  /// Straight-line distance to another [Location], in kilometres, using the
  /// Haversine formula. This is fast and needs no network call, which makes
  /// it ideal for the route-optimizer to run entirely on-device. It's an
  /// approximation of real walking/riding distance (it ignores roads and
  /// footpaths), but on a compact campus like Makerere it's a solid proxy —
  /// and it can later be swapped for Google's Distance Matrix API without
  /// changing any of the calling code (see MapsService).
  double distanceToKm(Location other) {
    const earthRadiusKm = 6371.0;

    final lat1 = _degToRad(latitude);
    final lat2 = _degToRad(other.latitude);
    final dLat = _degToRad(other.latitude - latitude);
    final dLon = _degToRad(other.longitude - longitude);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }

  @override
  String toString() => 'Location($name, $latitude, $longitude)';
}
