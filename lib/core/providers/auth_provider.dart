import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

class CurrentUserNotifier extends StateNotifier<AppUser?> {
  final AuthService _auth;
  StreamSubscription<fa.User?>? _sub;
  bool _isAuthenticating = false;
  bool _initialized = false;

  CurrentUserNotifier(this._auth) : super(null) {
    _sub = _auth.authStateChanges().listen((fa.User? fbUser) {
      debugPrint('[DEBUG] authStateChanges fired — fbUser == null: ${fbUser == null}, _isAuthenticating: $_isAuthenticating, _initialized: $_initialized');
      _onAuthChanged(fbUser);
    }, onError: (Object e) {
      debugPrint('[DEBUG] authStateChanges onError: $e');
      state = null;
    });
  }

  Future<void> _onAuthChanged(fa.User? fbUser) async {
    if (fbUser != null) {
      if (_isAuthenticating) return;
      try {
        await _auth.loadCurrentUser();
        if (_auth.currentUser != null) {
          state = _auth.currentUser;
        } else if (!_initialized) {
          state = null;
        }
        _initialized = true;
      } catch (_) {
        state = null;
      }
    } else if (fa.FirebaseAuth.instance.currentUser == null) {
      state = null;
      _initialized = true;
    }
  }

  Future<void> _persistRole(AppUserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    if (role == AppUserRole.spectator) {
      await prefs.setBool('hasSpectatorAccount', true);
    } else {
      await prefs.setBool('hasScorerAccount', true);
    }
  }

  Future<bool> hasSpectatorAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSpectatorAccount') ?? false;
  }

  Future<bool> hasScorerAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasScorerAccount') ?? false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> signUpSpectator({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    String? favoriteTournamentId,
  }) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpSpectator(
        name: name,
        email: email,
        password: password,
        phone: phone,
        address: address,
        favoriteTournamentId: favoriteTournamentId,
      );
      state = user;
      await _persistRole(AppUserRole.spectator);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signUpScorer({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    String? organization,
  }) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpScorer(
        name: name,
        email: email,
        password: password,
        phone: phone,
        address: address,
        organization: organization,
      );
      state = user;
      await _persistRole(AppUserRole.scorer);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signIn(String email, String password) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signIn(email, password);
      state = user;
      await _persistRole(user.role);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> switchRole(AppUserRole targetRole) async {
    if (state != null) {
      state = state!.copyWith(role: targetRole);
    } else {
      final fbUser = _auth.currentUser;
      state = AppUser(
        id: fbUser?.id ?? 'user',
        name: fbUser?.name ?? 'User',
        email: fbUser?.email ?? '',
        phone: fbUser?.phone ?? '',
        address: fbUser?.address ?? '',
        role: targetRole,
        createdAt: DateTime.now(),
      );
    }
    await _persistRole(targetRole);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = null;
    _initialized = false;
  }
}

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AppUser?>(
  (ref) => CurrentUserNotifier(ref.watch(authServiceProvider)),
);
