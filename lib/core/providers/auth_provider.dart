import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService());

/// Tracks whether the initial Firebase auth session restore has finished.
class AuthReadyNotifier extends StateNotifier<bool> {
  AuthReadyNotifier() : super(false);
  void markReady() => state = true;
}

final authReadyProvider =
    StateNotifierProvider<AuthReadyNotifier, bool>((ref) => AuthReadyNotifier());

class CurrentUserNotifier extends StateNotifier<AppUser?> {
  final AuthService _auth;
  final AuthReadyNotifier _ready;
  StreamSubscription<fa.User?>? _sub;
  bool _isAuthenticating = false;
  bool _initialized = false;
  bool _resolving = false;

  static const _kAuthRefreshTimeout = Duration(seconds: 4);

  CurrentUserNotifier(this._auth, this._ready) : super(null) {
    _sub = _auth.authStateChanges().listen((fa.User? fbUser) {
      _onAuthChanged(fbUser);
    }, onError: (Object e) {
      state = null;
      _markReady();
    });

    Future.delayed(_kAuthRefreshTimeout, () {
      if (!_initialized) {
        _markReady();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInitialized());
  }

  void _markReady() {
    if (_initialized) return;
    _initialized = true;
    _ready.markReady();
  }

  void _ensureInitialized() {
    if (_initialized || _isAuthenticating || _resolving) return;
    try {
      final fbUser = fa.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        _onAuthChanged(fbUser);
      }
    } catch (_) {
      _markReady();
    }
  }

  Future<void> _onAuthChanged(fa.User? fbUser) async {
    if (_resolving) return;
    _resolving = true;
    try {
      if (fbUser != null) {
        if (_isAuthenticating) return;
        try {
          final cached = await _readCachedUser();
          if (cached != null && cached.id == fbUser.uid) {
            state = cached;
            _markReady();
          }
          try {
            await _auth.loadCurrentUser().timeout(_kAuthRefreshTimeout);
            if (_auth.currentUser != null) {
              state = _auth.currentUser;
              await _cacheUser(_auth.currentUser!);
            }
          } catch (_) {}
          if (!_initialized) {
            state = _auth.currentUser ?? state;
            _markReady();
          }
        } catch (_) {
          state = null;
          _markReady();
        }
      } else {
        state = null;
        _markReady();
      }
    } finally {
      _resolving = false;
      if (!_initialized && !_isAuthenticating) {
        _markReady();
      }
    }
  }

  static const _kCachedUserKey = 'cached_app_user';

  Future<void> _cacheUser(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<AppUser?> _readCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedUserKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
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
    String? favoriteTournamentId,
  }) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpSpectator(
        name: name,
        email: email,
        password: password,
        favoriteTournamentId: favoriteTournamentId,
      );
      state = user;
      await _persistRole(AppUserRole.spectator);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpScorer(
        name: name,
        email: email,
        password: password,
        organization: organization,
      );
      state = user;
      await _persistRole(AppUserRole.scorer);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signUpSpectatorWithGoogle() async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpWithGoogle(role: AppUserRole.spectator);
      if (user == null) return;
      state = user;
      await _persistRole(AppUserRole.spectator);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signUpScorerWithGoogle({String? organization}) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpWithGoogle(
        role: AppUserRole.scorer,
        organization: organization,
      );
      if (user == null) return;
      state = user;
      await _persistRole(AppUserRole.scorer);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInAsSpectator(String email, String password) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signIn(email, password);
      if (user.role != AppUserRole.spectator) {
        await _auth.signOut();
        throw Exception('This email is registered as a Scorer. Please login from the Scorer section.');
      }
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInAsScorer(String email, String password) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signIn(email, password);
      if (user.role != AppUserRole.scorer) {
        await _auth.signOut();
        throw Exception('This email is registered as a Spectator. Please login from the Spectator section.');
      }
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInSpectatorWithGoogle() async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpWithGoogle(role: AppUserRole.spectator);
      if (user == null) return;
      if (user.role != AppUserRole.spectator) {
        await _auth.signOut();
        throw Exception('This email is registered as a Scorer. Please login from the Scorer section.');
      }
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInScorerWithGoogle() async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signUpWithGoogle(role: AppUserRole.scorer);
      if (user == null) return;
      if (user.role != AppUserRole.scorer) {
        await _auth.signOut();
        throw Exception('This email is registered as a Spectator. Please login from the Spectator section.');
      }
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInWithGoogle() async {
    await signInSpectatorWithGoogle();
  }

  Future<void> signIn(String email, String password) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.signIn(email, password);
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> reactivateAccount(String email, String password) async {
    _isAuthenticating = true;
    try {
      final user = await _auth.reactivateAccount(email, password);
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<bool> switchToRole(AppUserRole targetRole) async {
    if (state == null) return false;
    try {
      await _auth.switchToRole(targetRole);
      state = state!.copyWith(role: targetRole);
      await _persistRole(targetRole);
      await _cacheUser(state!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> softDeleteAccount(String email, String password) async {
    await _auth.softDeleteAccount(email, password);
    state = null;
    _initialized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserKey);
    } catch (_) {}
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
    await _cacheUser(state!);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = null;
    _initialized = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserKey);
    } catch (_) {}
  }
}

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AppUser?>(
  (ref) => CurrentUserNotifier(
    ref.watch(authServiceProvider),
    ref.read(authReadyProvider.notifier),
  ),
);

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.id,
);
