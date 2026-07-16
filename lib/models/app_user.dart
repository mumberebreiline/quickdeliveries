/// The two kinds of account the app supports. A single Firebase Auth
/// project holds both, but every account is tagged with exactly one role
/// here so customer and vendor identities stay logically separated even
/// though they share the same underlying `users` collection.
enum UserRole { customer, vendor }

/// A lightweight profile document stored at `users/{uid}` in Firestore.
/// This is intentionally separate from [FoodOrder]'s customerName/Phone
/// fields (which are just what a guest typed at checkout) — this is the
/// actual account record for anyone who signed up.
class AppUser {
  final String uid;
  final UserRole role;
  final String name;
  final String? phone;
  final String? email;
  final DateTime createdAt;

  const AppUser({
    required this.uid,
    required this.role,
    required this.name,
    this.phone,
    this.email,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      role: (map['role'] as String?) == 'vendor'
          ? UserRole.vendor
          : UserRole.customer,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
