// test/live_payload_names_stats_test.dart
// Guards the "spectator live Friendly Match shows real player names + stats"
// fix. Two layers:
//   1. The scorer's RTDB live payload is fully self-contained: it carries
//      player ids, resolved names, team names and complete batting/bowling
//      cards, so a spectator can render real names without any client-side
//      player lookup.
//   2. The spectator name resolver prefers that payload (players -> squads)
//      before falling back to the spectator's own (possibly stale) player list.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/ui/spectator/match_detail/view/spectator_match_detail_screen.dart';

const _t1Id = 'team_local_1000_1';
const _t2Id = 'team_local_1000_2';
const _virat = 'p_team_local_1000_1_virat_1';
const _rohit = 'p_team_local_1000_1_rohit_2';
const _bumrah = 'p_team_local_1000_2_bumrah_3';
const _shami = 'p_team_local_1000_2_shami_4';

Future<void> _seedFriendly(ScorerRepository repo) async {
  await repo.saveTeam(const ScorerTeam(
      id: _t1Id, name: 'India', shortCode: 'IND', tournamentId: 't_custom',
      playerIds: [_virat, _rohit]));
  await repo.saveTeam(const ScorerTeam(
      id: _t2Id, name: 'Pakistan', shortCode: 'PAK', tournamentId: 't_custom',
      playerIds: [_bumrah, _shami]));
  await repo.savePlayer(const ScorerPlayer(
      id: _virat, name: 'Virat Kohli', teamId: _t1Id,
      tournamentId: 't_custom', role: PlayerRole.batsman,
      battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.none));
  await repo.savePlayer(const ScorerPlayer(
      id: _rohit, name: 'Rohit Sharma', teamId: _t1Id,
      tournamentId: 't_custom', role: PlayerRole.batsman,
      battingStyle: BattingStyle.rightHand, bowlingStyle: BowlingStyle.none));
  await repo.savePlayer(const ScorerPlayer(
      id: _bumrah, name: 'Bumrah', teamId: _t2Id,
      tournamentId: 't_custom', role: PlayerRole.bowler,
      battingStyle: BattingStyle.rightHand,
      bowlingStyle: BowlingStyle.rightArmPace));
  await repo.savePlayer(const ScorerPlayer(
      id: _shami, name: 'Shami', teamId: _t2Id,
      tournamentId: 't_custom', role: PlayerRole.bowler,
      battingStyle: BattingStyle.rightHand,
      bowlingStyle: BowlingStyle.rightArmPace));
}

/// A live friendly match: India batting vs Pakistan, 3 balls bowled
/// (0, 4, 6 — all by Virat off Bumrah).
ScorerMatch _buildLiveFriendlyMatch() {
  final inn = Innings(
    id: 'inn_1_m_1',
    battingTeamId: _t1Id,
    bowlingTeamId: _t2Id,
    inningsNumber: 1,
    balls: [
      BallEvent(overNumber: 1, ballInOver: 1, batsmanId: _virat, bowlerId: _bumrah,
          runs: 0, extrasType: ExtrasType.none, extrasRuns: 0,
          isWicket: false, isBoundary: false, isSix: false,
          timestamp: DateTime(2026, 1, 1, 10)),
      BallEvent(overNumber: 1, ballInOver: 2, batsmanId: _virat, bowlerId: _bumrah,
          runs: 4, extrasType: ExtrasType.none, extrasRuns: 0,
          isWicket: false, isBoundary: true, isSix: false,
          timestamp: DateTime(2026, 1, 1, 10, 0, 1)),
      BallEvent(overNumber: 1, ballInOver: 3, batsmanId: _virat, bowlerId: _bumrah,
          runs: 6, extrasType: ExtrasType.none, extrasRuns: 0,
          isWicket: false, isBoundary: true, isSix: true,
          timestamp: DateTime(2026, 1, 1, 10, 0, 2)),
    ],
    battingOrder: const [_virat, _rohit],
    bowlingOrder: const [_bumrah],
    isComplete: false,
    strikerId: _virat,
    nonStrikerId: _rohit,
    currentBowlerId: _bumrah,
  );

  return ScorerMatch(
    id: 'm_1',
    tournamentId: 't_custom',
    team1Id: _t1Id,
    team2Id: _t2Id,
    venue: 'Ground',
    dateTime: DateTime(2026, 1, 1),
    format: MatchFormat.t20,
    overs: 20,
    status: MatchStatus.inProgress,
    playingXI1: const [_virat, _rohit],
    playingXI2: const [_bumrah, _shami],
    innings1: inn,
    currentInnings: 1,
  );
}

LiveMatchData _minimalLive({
  Map<String, String> players = const {},
  Map<String, String> squad1 = const {},
  Map<String, String> squad2 = const {},
}) {
  return LiveMatchData(
    status: 'inProgress',
    currentInnings: 1,
    battingTeamId: _t1Id,
    bowlingTeamId: _t2Id,
    score: const LiveMatchScore(runs: 0, wickets: 0, overs: 0, balls: 0),
    target: null,
    requiredRunRate: null,
    striker: const LiveBatter(
        playerId: _virat, name: '', runs: 0, balls: 0, fours: 0, sixes: 0),
    nonStriker: const LiveBatter(
        playerId: _rohit, name: '', runs: 0, balls: 0, fours: 0, sixes: 0),
    currentBowler: const LiveBowler(
        playerId: _bumrah, name: '', legalBalls: 0, maidens: 0, runs: 0,
        wickets: 0, wides: 0, noBalls: 0),
    thisOverBalls: const [],
    ballHistory: const [],
    lastUpdated: null,
    players: players,
    squad1: squad1,
    squad2: squad2,
  );
}

void main() {
  group('scorer RTDB live payload (friendly match)', () {
    test('is self-contained: real names + stats for every rendered player',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ScorerRepository(null);
      await _seedFriendly(repo);
      final container = ProviderContainer(overrides: [
        scorerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final payload = await container
          .read(scorerLiveMatchRepositoryProvider)
          .buildLiveMatchPayload(_buildLiveFriendlyMatch());

      // Teams + team ids.
      expect(payload['team1Id'], _t1Id);
      expect(payload['team2Id'], _t2Id);
      expect(payload['team1Name'], 'India');
      expect(payload['team2Name'], 'Pakistan');

      // Current innings + batting/bowling team ids.
      expect(payload['currentInnings'], 1);
      expect(payload['battingTeamId'], _t1Id);
      expect(payload['bowlingTeamId'], _t2Id);

      // Current score.
      final score = payload['score'] as Map;
      expect(score['runs'], 10);
      expect(score['wickets'], 0);
      expect(score['overs'], 0);
      expect(score['balls'], 3);

      // Striker / non-striker / current bowler: player ids + resolved names.
      final striker = payload['striker'] as Map;
      expect(striker['playerId'], _virat);
      expect(striker['name'], 'Virat Kohli');
      expect(striker['runs'], 10);
      expect(striker['balls'], 3);
      expect(striker['fours'], 1);
      expect(striker['sixes'], 1);

      final nonStriker = payload['nonStriker'] as Map;
      expect(nonStriker['playerId'], _rohit);
      expect(nonStriker['name'], 'Rohit Sharma');

      final bowler = payload['currentBowler'] as Map;
      expect(bowler['playerId'], _bumrah);
      expect(bowler['name'], 'Bumrah');
      expect(bowler['legalBalls'], 3);
      expect(bowler['runs'], 10);
      expect(bowler['wickets'], 0);

      // Batting card: every batter with name + stats.
      final battingCard = (payload['battingCard'] as List).cast<Map>();
      expect(
          battingCard.map((b) => b['name']),
          containsAll(['Virat Kohli', 'Rohit Sharma']));
      final v = battingCard.firstWhere((b) => b['playerId'] == _virat);
      expect(v['runs'], 10);
      expect(v['balls'], 3);
      expect(v['fours'], 1);
      expect(v['sixes'], 1);
      expect(v['status'], 'batting');
      expect(v['onStrike'], true);

      // Bowling card: every bowler with name + figures.
      final bowlingCard = (payload['bowlingCard'] as List).cast<Map>();
      final b = bowlingCard.firstWhere((x) => x['playerId'] == _bumrah);
      expect(b['name'], 'Bumrah');
      expect(b['legalBalls'], 3);
      expect(b['runs'], 10);
      expect(b['wickets'], 0);

      // Squads + flat playerId -> name map cover every referenced player.
      final squad1 = payload['squad1'] as Map;
      expect(squad1[_virat], 'Virat Kohli');
      expect(squad1[_rohit], 'Rohit Sharma');
      final squad2 = payload['squad2'] as Map;
      expect(squad2[_bumrah], 'Bumrah');
      expect(squad2[_shami], 'Shami');

      final players = payload['players'] as Map;
      expect(players[_virat], 'Virat Kohli');
      expect(players[_rohit], 'Rohit Sharma');
      expect(players[_bumrah], 'Bumrah');
      expect(players[_shami], 'Shami');
    });
  });

  group('spectator name resolution', () {
    const emptyState = SpectatorHomeState(players: [], isLoading: false);

    test('prefers the RTDB payload players map over the client lookup', () {
      final live = _minimalLive(players: const {_virat: 'Virat Kohli'});
      expect(resolvePlayerName(emptyState, live, _virat), 'Virat Kohli');
    });

    test('falls back to the squad maps inside the payload', () {
      final live = _minimalLive(squad2: const {_shami: 'Shami'});
      expect(resolvePlayerName(emptyState, live, _shami), 'Shami');
    });

    test('falls back to the client player list when the payload lacks the id',
        () {
      const state = SpectatorHomeState(
        isLoading: false,
        players: [
          ScorerPlayer(
            id: _virat,
            name: 'Virat Kohli',
            teamId: _t1Id,
            tournamentId: 't_custom',
            role: PlayerRole.batsman,
            battingStyle: BattingStyle.rightHand,
            bowlingStyle: BowlingStyle.none,
          ),
        ],
      );
      // No payload at all (e.g. completed match).
      expect(resolvePlayerName(state, null, _virat), 'Virat Kohli');
      // Payload present but does not know this player.
      expect(resolvePlayerName(state, _minimalLive(), _virat), 'Virat Kohli');
    });

    test('a stale spectator player list never overrides payload names', () {
      final live = _minimalLive(players: const {_virat: 'Virat Kohli'});
      // The client list is empty — before the fix the screen would render the
      // garbled id here.
      expect(resolvePlayerName(emptyState, live, _virat), 'Virat Kohli');
      expect(resolvePlayerName(emptyState, live, _virat),
          isNot(contains('team_local_1000')));
    });
  });
}
