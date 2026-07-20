import 'location.dart';

enum HazardSeverity { low, medium, high }

enum HazardCondition { always, duringRain, atNight }

/// A known problem spot on campus — reported by the vendor from lived
/// experience ("this path floods when it rains," "this gate closes at
/// 6pm"). No API can supply this; it's the one genuinely crowdsourced
/// route factor.
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
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      severity: HazardSeverity.values.firstWhere(
        (s) => s.name == map['severity'],
        orElse: () => HazardSeverity.low,
      ),
      activeWhen: HazardCondition.values.firstWhere(
        (c) => c.name == map['activeWhen'],
        orElse: () => HazardCondition.always,
      ),
      reportedAt:
          DateTime.tryParse(map['reportedAt'] as String? ?? '') ??
          DateTime.now(),
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
