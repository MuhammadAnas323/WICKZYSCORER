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
/// The splash screen waits for this before deciding where to navigate so we
/// never flash the role-selection / sign-in screen for an already-logged-in user.
class AuthReadyNotifier extends StateNotifier<bool> {
  AuthReadyNotifier() : super(false);
  void markReady() => state = true;
}

/// Exposes a boolean that flips to `true` once the current user (or the
/// absence of one) has been established after an app cold start.
final authReadyProvider =
    StateNotifierProvider<AuthReadyNotifier, bool>((ref) => AuthReadyNotifier());

class CurrentUserNotifier extends StateNotifier<AppUser?> {
  final AuthService _auth;
  final AuthReadyNotifier _ready;
  StreamSubscription<fa.User?>? _sub;
  bool _isAuthenticating = false;
  bool _initialized = false;
  bool _resolving = false;

  /// Upper bound for the Firestore-backed profile refresh during startup. If a
  /// flaky/offline network makes the `.get()` hang, we still want the splash to
  /// navigate instead of getting stuck forever.
  static const _kAuthRefreshTimeout = Duration(seconds: 4);

  CurrentUserNotifier(this._auth, this._ready) : super(null) {
    _sub = _auth.authStateChanges().listen((fa.User? fbUser) {
      debugPrint('[DEBUG] authStateChanges fired — fbUser == null: ${fbUser == null}, _isAuthenticating: $_isAuthenticating, _initialized: $_initialized');
      _onAuthChanged(fbUser);
    }, onError: (Object e) {
      debugPrint('[DEBUG] authStateChanges onError: $e');
      state = null;
      _markReady();
    });

    // The authStateChanges stream emits the restored session, but be defensive:
    // kick off the same resolution straight away for already-restored sessions.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInitialized());
  }

  /// Flipped exactly once so the splash can never wait on the session forever.
  /// Safe to call from any resolution path (idempotent).
  void _markReady() {
    if (_initialized) return;
    _initialized = true;
    _ready.markReady();
  }

  /// Resolves the current user if the stream has not fired yet (e.g. session
  /// restored before the listener was attached).
  void _ensureInitialized() {
    if (_initialized || _isAuthenticating || _resolving) return;
    try {
      final fbUser = fa.FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        _onAuthChanged(fbUser);
      } else {
        _markReady();
      }
    } catch (_) {
      // Firebase not available (e.g. widget tests) — nothing to restore, so the
      // splash can proceed as an anonymous visitor.
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
          // Fast path: if we have a locally cached profile for this account, use
          // it immediately so the splash can navigate without a slow network call.
          final cached = await _readCachedUser();
          if (cached != null && cached.id == fbUser.uid && !_initialized) {
            state = cached;
            _markReady();
          }
          // Refresh from Firestore in the background (never blocks startup),
          // bounded so a hanging network call can't strand the splash.
          try {
            await _auth.loadCurrentUser().timeout(_kAuthRefreshTimeout);
            if (_auth.currentUser != null) {
              state = _auth.currentUser;
              await _cacheUser(_auth.currentUser!);
            }
          } catch (_) {
            // Keep the cached profile; network failure shouldn't log the user out.
          }
          if (!_initialized) {
            state = _auth.currentUser ?? state;
            _markReady();
          }
        } catch (_) {
          state = null;
          _markReady();
        }
      } else if (fa.FirebaseAuth.instance.currentUser == null) {
        state = null;
        _markReady();
      }
    } finally {
      _resolving = false;
      // Safety net: a cold-start resolution (no sign-in in flight) must always
      // flip the ready flag so the splash can move on.
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
    } catch (_) {
      // Best effort.
    }
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
      state = user;
      await _persistRole(AppUserRole.scorer);
      await _cacheUser(user);
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> signInWithGoogle() async {
    _isAuthenticating = true;
    try {
      // Default to spectator if new, but signUpWithGoogle handles existing profile roles.
      final user = await _auth.signUpWithGoogle(role: AppUserRole.spectator);
      state = user;
      await _persistRole(user.role);
      await _cacheUser(user);
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
      await _cacheUser(user);
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

/// The signed-in user's id (null when signed out). Kept as a separate, cheap
/// provider so long-lived services (e.g. the match alert listener) can watch
/// just the uid without depending on the whole [currentUserProvider] notifier.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.id,
);
