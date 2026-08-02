import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Exposes login state AND role to the whole app via Provider. This is
/// the mechanism behind "one login button, two kinds of accounts" —
/// signIn() itself resolves the signed-in account's role before
/// returning, so the login screen can read `role` immediately afterward
/// and decide where to send them, with no separate "which login screen
/// did you use" logic anywhere.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;
  StreamSubscription<User?>? _authSub;

  User? _user;
  UserRole? _role;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({AuthService? authService, UserService? userService})
    : _authService = authService ?? AuthService(),
      _userService = userService ?? UserService() {
    _user = _authService.currentUser;
    if (_user != null) {
      _refreshRole(_user!.uid);
    }
    // Keeps role in sync across app restarts / sign-outs from elsewhere.
    _authSub = _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await _refreshRole(user.uid);
      } else {
        _role = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  UserRole? get role => _role;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _refreshRole(String uid) async {
    final profile = await _userService.getProfile(uid);
    // Anonymous guests have no email at all (isAnonymous == true) — this
    // is only ever a real address for someone who actually logged in
    // with email/password, which is exactly who this should apply to.
    final loginEmail = _authService.currentUser?.email;

    if (profile != null) {
      _role = profile.role;
      // The one genuine improvement here: instead of requiring someone
      // to manually retype the same email into Firestore after it was
      // already typed once into Firebase Console's Authentication tab
      // (or the app's own registration form), this fills it in
      // automatically the first time they ever sign in — no separate
      // manual step needed for notifications to reach the right inbox.
      if ((profile.email == null || profile.email!.isEmpty) &&
          loginEmail != null &&
          loginEmail.isNotEmpty) {
        await _userService.updateMyEmail(uid, loginEmail);
      }
    } else {
      // No Firestore profile yet — default to customer and create one,
      // rather than leave the app unsure which experience to show.
      await _userService.createProfile(
        uid: uid,
        role: UserRole.customer,
        email: loginEmail,
      );
      _role = UserRole.customer;
    }
  }

  /// Works for both customer and vendor accounts — same button, same
  /// call. `role` is populated by the time this returns, so the caller
  /// can safely check `authProvider.role` right after `await`ing this.
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final credential = await _authService.signIn(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _refreshRole(credential.user!.uid);
      }
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign-in failed';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Customer sign-up only — there is deliberately no "register as
  /// vendor" option anywhere in the UI. The vendor's one account is
  /// provisioned directly in Firebase Console and tagged role: vendor in
  /// Firestore by hand; it never goes through self-service registration.
  Future<bool> registerAsCustomer(
    String email,
    String password, {
    String? name,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _userService.createProfile(
          uid: credential.user!.uid,
          role: UserRole.customer,
          name: name,
          phone: phone,
        );
        _role = UserRole.customer;
      }
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Registration failed';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _authService.sendPasswordReset(email);

  Future<void> signOut() => _authService.signOut();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
