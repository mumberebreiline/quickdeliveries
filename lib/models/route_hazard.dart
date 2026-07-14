import 'location.dart';

/// How much a hazard slows things down when it's active.
enum HazardSeverity { low, medium, high }

/// When a hazard actually applies. Some problems (a broken path) are
/// permanent; others (a muddy shortcut) only matter in certain conditions.
enum HazardCondition { always, duringRain, atNight }

/// A known problem spot on campus — reported by the vendor from lived
/// experience, since no API can tell you "this footpath floods when it
/// rains" or "this gate closes at 6pm." This is the one route factor that's
/// genuinely crowdsourced rather than fetched from a service.
class RouteHazard {
  final String id;
  final String description;
  final double latitude;
  final double longitude;
  final HazardSeverity severity;
  final HazardCondition activeWhen;
  final DateTime reportedAt;
  final bool isActive;

  const RouteHazard({
    required this.id,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.activeWhen,
    required this.reportedAt,
    this.isActive = true,
  });

  /// How many extra minutes this hazard adds to a stop near it, given
  /// current conditions. Returns 0 if the hazard doesn't apply right now
  /// (e.g. a "floods when raining" hazard on a dry day).
  double penaltyMinutes({
    required bool isRainingNow,
    required bool isNightNow,
  }) {
    if (!isActive) return 0;

    final applies = switch (activeWhen) {
      HazardCondition.always => true,
      HazardCondition.duringRain => isRainingNow,
      HazardCondition.atNight => isNightNow,
    };
    if (!applies) return 0;

    return switch (severity) {
      HazardSeverity.low => 2,
      HazardSeverity.medium => 5,
      HazardSeverity.high => 10,
    };
  }

  /// Whether this hazard is close enough to a delivery point to matter.
  /// 150m covers "somewhere along the path to this building" without
  /// pulling in hazards from unrelated parts of campus.
  bool isNear(Location location, {double radiusKm = 0.15}) {
    final hazardLocation = Location(
      id: 'hazard_$id',
      name: description,
      latitude: latitude,
      longitude: longitude,
    );
    return hazardLocation.distanceToKm(location) <= radiusKm;
  }

  factory RouteHazard.fromMap(Map<String, dynamic> map, String id) {
    return RouteHazard(
      id: id,
      description: map['description'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      severity: HazardSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => HazardSeverity.low,
      ),
      activeWhen: HazardCondition.values.firstWhere(
        (c) => c.name == map['activeWhen'],
        orElse: () => HazardCondition.always,
      ),
      reportedAt: DateTime.parse(map['reportedAt'] as String),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity.name,
      'activeWhen': activeWhen.name,
      'reportedAt': reportedAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}
