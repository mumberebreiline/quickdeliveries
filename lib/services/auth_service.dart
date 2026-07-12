import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth. In v1 only the vendor logs in (customers order as
/// guests, giving name + phone at checkout) — but this is written so adding
/// customer accounts later is just a new screen, not a new service.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Used once, to create the vendor's account (or by an admin later to add
  /// more vendor accounts).
  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() => _auth.signOut();
}
