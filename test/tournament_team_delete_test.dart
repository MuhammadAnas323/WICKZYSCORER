// test/tournament_team_delete_test.dart
// Verifies the team card has no delete button and that long-pressing a team
// shows a confirm dialog which then removes the team.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/app_user.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/ui/scorer/tournaments/view/tournament_detail_view_screen.dart';

class MockAuthService implements AuthService {
  @override
  AppUser? get currentUser => null;

  @override
  Stream<fa.User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> loadCurrentUser() async {}

  @override
  Future<AppUser> signIn(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AppUser> signUpSpectator({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('team card has no delete button; long-press removes the team',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);
    await repo.saveTournament(ScorerTournament(
      id: 't1',
      name: 'Test Cup',
      ownerId: 'owner',
      format: MatchFormat.t20,
      customOvers: 20,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 2, 1),
      venue: 'Ground',
      numTeams: 1,
      teamIds: const ['team1'],
      pointsRules: const PointsRules(),
    ));
    await repo.saveTeam(ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: const [],
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scorerRepositoryProvider.overrideWithValue(repo),
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: const MaterialApp(
          home: TournamentDetailViewScreen(tournamentId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The team card is visible and has NO delete icon button.
    expect(find.text('Kings XI'), findsOneWidget);
    final teamCard = find
        .ancestor(of: find.text('Kings XI'), matching: find.byType(GestureDetector))
        .first;
    expect(
      find.descendant(
        of: teamCard,
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );

    // Long-press the team card -> confirm dialog appears.
    await tester.longPress(find.text('Kings XI'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Team?'), findsOneWidget);

    // Confirm removal -> team is gone from the list.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Kings XI'), findsNothing);
  });
}
