import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;

class MockAuthService implements AuthService {
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<fa.User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> loadCurrentUser() async {}

  @override
  Future<AppUser> signIn(String email, String password) async {
    _user = AppUser(
      id: '123',
      name: 'Test User',
      email: email,
      phone: '',
      address: '',
      role: email.contains('scorer') ? AppUserRole.scorer : AppUserRole.spectator,
      createdAt: DateTime.now(),
    );
    return _user!;
  }

  @override
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    _user = AppUser(
      id: 'scorer_123',
      name: name,
      email: email,
      phone: '',
      address: '',
      role: AppUserRole.scorer,
      organization: organization,
      createdAt: DateTime.now(),
    );
    return _user!;
  }

  @override
  Future<AppUser> signUpSpectator({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  }) async {
    _user = AppUser(
      id: 'spectator_123',
      name: name,
      email: email,
      phone: '',
      address: '',
      role: AppUserRole.spectator,
      favoriteTournamentId: favoriteTournamentId,
      createdAt: DateTime.now(),
    );
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Role Navigation & Switch Role Logic', () {
    late MockAuthService mockAuth;
    late CurrentUserNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthService();
      notifier = CurrentUserNotifier(mockAuth, AuthReadyNotifier());
    });

    test('Step 1: Sign up as Scorer only -> sets hasScorerAccount, role is Scorer', () async {
      expect(await notifier.hasScorerAccount(), isFalse);
      expect(await notifier.hasSpectatorAccount(), isFalse);

      await notifier.signUpScorer(
        name: 'Scorer User',
        email: 'scorer@test.com',
        password: 'password',
      );

      expect(notifier.debugState?.role, equals(AppUserRole.scorer));
      expect(notifier.debugState?.isScorer, isTrue);
      expect(await notifier.hasScorerAccount(), isTrue);
      expect(await notifier.hasSpectatorAccount(), isFalse);
    });

    test('Step 2: From Scorer Profile, Switch to Spectator when no Spectator account exists -> goes to Spectator Sign Up', () async {
      // Setup Scorer account
      await notifier.signUpScorer(
        name: 'Scorer User',
        email: 'scorer@test.com',
        password: 'password',
      );

      final isScorer = notifier.debugState?.isScorer ?? false;
      expect(isScorer, isTrue);

      final hasSpectator = await notifier.hasSpectatorAccount();
      expect(hasSpectator, isFalse);

      // Since hasSpectator is false, app signs out and navigates to spectator signup
      await notifier.signOut();
      expect(notifier.debugState, isNull);
    });

    test('Step 3: Complete Spectator Sign Up -> sets hasSpectatorAccount, role is Spectator', () async {
      await notifier.signUpSpectator(
        name: 'Spectator User',
        email: 'spectator@test.com',
        password: 'password',
      );

      expect(notifier.debugState?.role, equals(AppUserRole.spectator));
      expect(notifier.debugState?.isSpectator, isTrue);
      expect(await notifier.hasSpectatorAccount(), isTrue);
    });

    test('Step 4: From Spectator Profile, Switch to Scorer when Scorer account exists -> switches role to Scorer', () async {
      // Set initial prefs: both accounts exist
      SharedPreferences.setMockInitialValues({
        'hasScorerAccount': true,
        'hasSpectatorAccount': true,
      });

      // Currently logged in as Spectator
      await notifier.signUpSpectator(
        name: 'Spectator User',
        email: 'spectator@test.com',
        password: 'password',
      );

      expect(notifier.debugState?.isSpectator, isTrue);

      // Check if target role (Scorer) has account
      final hasScorer = await notifier.hasScorerAccount();
      expect(hasScorer, isTrue);

      // Since Scorer account exists, switch role directly to Scorer
      await notifier.switchRole(AppUserRole.scorer);
      expect(notifier.debugState?.isScorer, isTrue);
      expect(notifier.debugState?.role, equals(AppUserRole.scorer));
    });
  });
}

extension CurrentUserNotifierTestX on CurrentUserNotifier {
  AppUser? get debugState => state;
}
