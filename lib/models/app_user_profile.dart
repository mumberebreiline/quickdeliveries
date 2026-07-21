/// Every Firebase Auth account is tagged with one of these — this is the
/// actual mechanism behind "one login button, two kinds of accounts."
/// Both share the same Authentication system; this Firestore-stored role
/// is what tells the app which experience to show after sign-in.
enum UserRole { customer, vendor }

class AppUserProfile {
  final String uid;
  final UserRole role;
  final String? name;
  final String? phone;
  final DateTime createdAt;

  const AppUserProfile({
    required this.uid,
    required this.role,
    required this.createdAt,
    this.name,
    this.phone,
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
}
