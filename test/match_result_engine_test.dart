import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/data/engines/match_result_engine.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/match_result.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';

final _l10n = AppLocalizations(const Locale('en'));

Innings _innings(
  String id, {
  required String battingTeamId,
  required String bowlingTeamId,
  required int inningsNumber,
  required int runs,
  int wickets = 0,
  bool isComplete = true,
}) {
  final balls = <BallEvent>[];
  var runTotal = 0;
  for (var i = 0; i < runs; i++) {
    final remaining = runs - runTotal;
    final r = remaining > 6 ? 6 : remaining;
    balls.add(BallEvent(
      overNumber: (balls.length ~/ 6) + 1,
      ballInOver: (balls.length % 6) + 1,
      batsmanId: '${battingTeamId}_b$i',
      bowlerId: '${bowlingTeamId}_b',
      runs: r,
      extrasType: ExtrasType.none,
      extrasRuns: 0,
      isWicket: false,
      isBoundary: r == 4,
      isSix: r == 6,
      timestamp: DateTime.now(),
    ));
    runTotal += r;
  }
  for (var i = 0; i < wickets; i++) {
    balls.add(BallEvent(
      overNumber: (balls.length ~/ 6) + 1,
      ballInOver: (balls.length % 6) + 1,
      batsmanId: '${battingTeamId}_w$i',
      bowlerId: '${bowlingTeamId}_b',
      runs: 0,
      extrasType: ExtrasType.none,
      extrasRuns: 0,
      isWicket: true,
      isBoundary: false,
      isSix: false,
      timestamp: DateTime.now(),
    ));
  }
  return Innings(
    id: id,
    battingTeamId: battingTeamId,
    bowlingTeamId: bowlingTeamId,
    inningsNumber: inningsNumber,
    balls: balls,
    battingOrder: const [],
    bowlingOrder: const [],
    isComplete: isComplete,
  );
}

ScorerMatch _match({
  required Innings? innings1,
  required Innings? innings2,
  Innings? superOverInnings1,
  Innings? superOverInnings2,
  bool superOverPlayed = false,
  MatchStatus status = MatchStatus.completed,
  List<String> playingXI1 = const [],
  List<String> playingXI2 = const [],
}) {
  return ScorerMatch(
    id: 'm',
    tournamentId: 't',
    team1Id: 'team1',
    team2Id: 'team2',
    venue: '',
    dateTime: DateTime.now(),
    format: MatchFormat.t20,
    overs: 20,
    status: status,
    playingXI1: playingXI1,
    playingXI2: playingXI2,
    currentInnings: superOverPlayed ? 4 : 2,
    innings1: innings1,
    innings2: innings2,
    superOverPlayed: superOverPlayed,
    superOverInnings1: superOverInnings1,
    superOverInnings2: superOverInnings2,
  );
}

void main() {
  group('MatchResultEngine.compute', () {
    test('chasing team wins by wickets', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 150,
            wickets: 4),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 151,
            wickets: 3),
        playingXI2: List.generate(11, (i) => 'p$i'),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team2');
      expect(r.loserTeamId, 'team1');
      expect(r.type, MatchResultType.byWickets);
      expect(r.margin, 7);
      expect(r.resultText, contains('Team B won by 7 wickets'));
      expect(r.losingText, contains('Team A lost by 7 wickets'));
    });

    test('first team wins by runs when chase falls short', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 180),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 160,
            wickets: 6),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team1');
      expect(r.loserTeamId, 'team2');
      expect(r.type, MatchResultType.byRuns);
      expect(r.margin, 20);
      expect(r.resultText, contains('Team A won by 20 runs'));
      expect(r.losingText, contains('Team B lost by 20 runs'));
    });

    test('chase tied exactly is a tie, not a win', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 120),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 120,
            wickets: 5),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.isTie, isTrue);
      expect(r.winnerTeamId, isNull);
      expect(r.loserTeamId, isNull);
      expect(r.type, MatchResultType.tie);
    });

    test('target reached exactly is a win by wickets, not a tie', () {
      // Target is 121; scoring exactly 121 (target) wins by wickets.
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 120),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 121,
            wickets: 0),
        playingXI2: List.generate(11, (i) => 'p$i'),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team2');
      expect(r.type, MatchResultType.byWickets);
      expect(r.margin, 10);
    });

    test('all-out chase below target is a win by runs', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 90),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 80,
            wickets: 10),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team1');
      expect(r.type, MatchResultType.byRuns);
      expect(r.margin, 10);
    });

    test('super over decides the match', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 100),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 100),
        superOverPlayed: true,
        superOverInnings1: _innings('so1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 3,
            runs: 12),
        superOverInnings2: _innings('so2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 4,
            runs: 8),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team1');
      expect(r.loserTeamId, 'team2');
      expect(r.type, MatchResultType.superOver);
      expect(r.isSuperOver, isTrue);
      expect(r.resultText, contains('Team A won by 4 runs (Super Over)'));
      expect(r.losingText, contains('Team B lost by 4 runs (Super Over)'));
    });

    test('super over chased by wickets', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 100),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 100),
        superOverPlayed: true,
        superOverInnings1: _innings('so1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 3,
            runs: 10,
            wickets: 1),
        superOverInnings2: _innings('so2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 4,
            runs: 11,
            wickets: 1),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.winnerTeamId, 'team2');
      expect(r.type, MatchResultType.superOver);
      expect(r.margin, 1);
      expect(r.resultText, contains('Team B won by 1 wickets'));
    });

    test('super over tied stays a tie', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 100),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 100),
        superOverPlayed: true,
        superOverInnings1: _innings('so1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 3,
            runs: 10),
        superOverInnings2: _innings('so2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 4,
            runs: 10),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.isTie, isTrue);
      expect(r.winnerTeamId, isNull);
      expect(r.isSuperOver, isTrue);
    });

    test('abandoned match has no winner and is a no-result', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 50,
            isComplete: false),
        innings2: null,
        status: MatchStatus.abandoned,
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.isNoResult, isTrue);
      expect(r.winnerTeamId, isNull);
      expect(r.loserTeamId, isNull);
      expect(r.type, MatchResultType.abandoned);
    });

    test('incomplete innings have no result', () {
      final match = _match(
        innings1: _innings('i1',
            battingTeamId: 'team1',
            bowlingTeamId: 'team2',
            inningsNumber: 1,
            runs: 50),
        innings2: _innings('i2',
            battingTeamId: 'team2',
            bowlingTeamId: 'team1',
            inningsNumber: 2,
            runs: 40,
            isComplete: false),
      );
      final r = MatchResultEngine.compute(
          match: match, team1Name: 'Team A', team2Name: 'Team B', l10n: _l10n);
      expect(r.isNoResult, isTrue);
      expect(r.winnerTeamId, isNull);
    });
  });
}
