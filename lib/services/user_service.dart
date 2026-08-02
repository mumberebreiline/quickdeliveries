import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user_profile.dart';

/// Keeps customer and vendor identities clearly separated in Firebase.
/// Every account gets a `users/{uid}` document tagged with its role —
/// the one source of truth for "is this person a customer or the
/// vendor." Nothing else in the app should guess based on which screen
/// someone logged in from, since there's only one login screen now.
class UserService {
  final CollectionReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('users');

  Future<void> createProfile({
    required String uid,
    required UserRole role,
    String? name,
    String? phone,
    String? email,
  }) {
    return _ref
        .doc(uid)
        .set(
          AppUserProfile(
            uid: uid,
            role: role,
            name: name,
            phone: phone,
            email: email,
            createdAt: DateTime.now(),
          ).toMap(),
          SetOptions(merge: true),
        );
  }

  Future<AppUserProfile?> getProfile(String uid) async {
    final doc = await _ref.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUserProfile.fromMap(doc.data()!, uid);
  }

  /// Auto-captures the login email onto a profile, without touching
  /// name/phone/role/anything else. Deliberately a separate, narrow
  /// method rather than reusing createProfile() for this — that one
  /// writes every field it's given, including explicit nulls for
  /// anything not passed in, which would have silently wiped out an
  /// existing name/phone the moment this ran on an already-set-up
  /// account. This only ever sends the one field it actually means to
  /// change.
  Future<void> updateMyEmail(String uid, String email) {
    return _ref.doc(uid).set({'email': email}, SetOptions(merge: true));
  }

  /// Every account tagged as a delivery guy — this is the list the
  /// admin picks from when assigning a batch of orders. Provisioned by
  /// hand in Firebase Console + Firestore, same as the admin's own
  /// account — no self-service "sign up as delivery guy" option.
  Stream<List<AppUserProfile>> streamDeliveryGuys() {
    return _ref
        .where('role', isEqualTo: UserRole.deliveryGuy.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUserProfile.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// There's only one vendor account in this whole system (tagged
  /// either 'admin' or the legacy 'vendor' value) — this is what lets
  /// the customer's order screen offer a "contact us" option without
  /// needing to know her uid ahead of time.
  Future<AppUserProfile?> getVendorProfile() async {
    for (final roleName in [UserRole.admin.name, UserRole.vendor.name]) {
      final snapshot = await _ref
          .where('role', isEqualTo: roleName)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return AppUserProfile.fromMap(doc.data(), doc.id);
      }
    }
    return null;
  }

  /// Called from the delivery tracking screen as he moves — this is
  /// what the admin's "watch over where the delivery guys are" screen
  /// actually reads. Writing to his own users/{uid} document is already
  /// allowed by the existing Firestore rules (a user can always write
  /// their own profile), so no rules change was needed for this.
  Future<void> updateMyLocation({
    required String uid,
    required double latitude,
    required double longitude,
  }) {
    return _ref.doc(uid).set({
      'currentLatitude': latitude,
      'currentLongitude': longitude,
      'locationUpdatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Called once a delivery is complete — clears his marker off the
  /// admin's live map rather than leaving a stale "last known position"
  /// showing forever after he's actually stopped moving.
  Future<void> clearMyLocation(String uid) {
    return _ref.doc(uid).set({
      'currentLatitude': null,
      'currentLongitude': null,
      'locationUpdatedAt': null,
    }, SetOptions(merge: true));
  }
}
