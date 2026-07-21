import 'dart:math';

/// A physical point on campus — a hall of residence, lecture block, the
/// vendor's kitchen, etc. Anything that can be a delivery destination or
/// route starting point.
class Location {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;

  const Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  /// Straight-line distance to another [Location], in kilometres, using
  /// the Haversine formula. No network call needed — fast enough to run
  /// the route optimizer entirely on-device. It's an approximation of
  /// real walking/riding distance (ignores roads/footpaths), but on a
  /// compact campus like Makerere it's a solid proxy.
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
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown location',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
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
}
