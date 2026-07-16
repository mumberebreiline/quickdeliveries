import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../services/customer_auth_service.dart';

/// Same shape as the vendor's AuthProvider, but wired to
/// [CustomerAuthService] so the two account systems never share state.
/// A null [user] just means "browsing as guest" — never an error state.
class CustomerAuthProvider extends ChangeNotifier {
  final CustomerAuthService _service;
  StreamSubscription<User?>? _authSub;

  User? _user;
  AppUser? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  CustomerAuthProvider({CustomerAuthService? service})
    : _service = service ?? CustomerAuthService() {
    _user = _service.currentUser;
    _authSub = _service.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _service.fetchProfile(user.uid).then((profile) {
          _profile = profile;
          notifyListeners();
        });
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  AppUser? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _service.signIn(email: email, password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign-in failed';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      await _service.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? 'Sign-up failed';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() => _service.signOut();

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
