/// Every Firebase Auth account is tagged with one of these — this is the
/// actual mechanism behind "one login button, several kinds of accounts."
/// All share the same Authentication system; this Firestore-stored role
/// is what tells the app which experience to show after sign-in.
///
/// `vendor` is kept as a legacy value rather than removed — the one
/// existing account was already tagged that way in Firestore before the
/// admin/delivery split was introduced, and there's no reason to force a
/// manual Firestore edit just to rename it. Everywhere the app checks
/// "is this the admin," it treats `admin` and `vendor` as the same thing
/// (see [UserRole.isAdmin]) — new accounts should be tagged `admin`
/// going forward, but old ones don't break.
enum UserRole { customer, vendor, admin, deliveryGuy }

extension UserRoleX on UserRole {
  bool get isAdmin => this == UserRole.admin || this == UserRole.vendor;
}

class AppUserProfile {
  final String uid;
  final UserRole role;
  final String? name;
  final String? phone;
  final DateTime createdAt;

  /// Only meaningfully set for delivery guys while they're actively out
  /// on a delivery — this is what powers the admin's "watch over where
  /// the delivery guys are" screen. Null for anyone not currently
  /// tracking (customers, the admin herself, or a delivery guy between
  /// deliveries).
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? locationUpdatedAt;

  const AppUserProfile({
    required this.uid,
    required this.role,
    required this.createdAt,
    this.name,
    this.phone,
    this.currentLatitude,
    this.currentLongitude,
    this.locationUpdatedAt,
  });

  factory AppUserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return AppUserProfile(
      uid: uid,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.customer,
      ),
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      currentLatitude: (map['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (map['currentLongitude'] as num?)?.toDouble(),
      locationUpdatedAt: DateTime.tryParse(
        map['locationUpdatedAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'name': name,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Without this, two AppUserProfile instances with the exact same uid
  // are still "different" as far as Dart is concerned — comparison
  // falls back to "is this literally the same object in memory."
  // That's exactly what broke the delivery-guy dropdown on Assign
  // Orders: every new Firestore snapshot builds brand new instances, so
  // a previously-selected profile stopped matching anything in the
  // freshly rebuilt list the moment any snapshot came in, even though
  // it was still "the same person." Same uid should always mean the
  // same profile, so equality is defined on that alone.
  @override
  bool operator ==(Object other) => other is AppUserProfile && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
