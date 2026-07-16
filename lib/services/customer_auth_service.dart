import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Handles customer sign-up/sign-in. Deliberately its own service, separate
/// from the vendor's [AuthService] — a customer account is created with
/// role='customer' written to `users/{uid}` the moment it's made, and the
/// vendor login flow never touches this collection with that role. Ordering
/// as a guest (no account) still works everywhere this isn't used; this
/// only backs the *optional* "sign up" corner button.
class CustomerAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates the Firebase Auth account AND its `users/{uid}` profile
  /// document with role='customer', in one step — a customer can never end
  /// up without a role tag.
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final profile = AppUser(
      uid: uid,
      role: UserRole.customer,
      name: name,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(profile.toMap());

    return credential;
  }

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();
}
