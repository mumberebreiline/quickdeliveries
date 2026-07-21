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
  }) {
    return _ref
        .doc(uid)
        .set(
          AppUserProfile(
            uid: uid,
            role: role,
            name: name,
            phone: phone,
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
}
