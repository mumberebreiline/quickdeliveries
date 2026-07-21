import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Auth — one email/password system shared
/// by both customer and vendor accounts. Which experience someone gets
/// after signing in is decided by their role in Firestore (see
/// UserService), not by which auth method they used.
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

  /// Lets someone place an order without ever seeing a login screen.
  /// If nobody's signed in yet, this quietly signs them in anonymously —
  /// they get a real Firebase Auth UID (so `userId` on their order, and
  /// "My Orders" filtering by it, still work exactly as before) without
  /// typing an email or password. If they later actually log in or
  /// register through the real login screen, that replaces this
  /// anonymous session with their real one.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }
}
