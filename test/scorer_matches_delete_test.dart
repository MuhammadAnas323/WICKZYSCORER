import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/matches/view/scorer_matches_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('delete match removes it from the matches list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = ScorerRepository(null);

    await repo.saveTeam(ScorerTeam(
      id: 'team1',
      name: 'Kings XI',
      shortCode: 'KX',
      tournamentId: 't1',
      playerIds: const [],
    ));
    await repo.saveTeam(ScorerTeam(
      id: 'team2',
      name: 'Lions',
      shortCode: 'LI',
      tournamentId: 't1',
      playerIds: const [],
    ));
    await repo.saveMatch(ScorerMatch(
      id: 'm1',
      tournamentId: 't1',
      team1Id: 'team1',
      team2Id: 'team2',
      venue: 'Ground',
      dateTime: DateTime.now(),
      format: MatchFormat.t20,
      overs: 20,
      status: MatchStatus.scheduled,
      playingXI1: const [],
      playingXI2: const [],
      currentInnings: 1,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [scorerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ScorerMatchesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kings XI  vs  Lions'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet'), findsOneWidget);
    expect(await repo.getMatches(), isEmpty);
  });
}
