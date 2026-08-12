// test/tournament_progression_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/tournament_progression.dart';

void main() {
  group('TournamentProgressionEngine', () {
    late TournamentProgressionEngine engine;

    setUp(() {
      engine = TournamentProgressionEngine();
    });

    ScheduleFixture _fx({
      required String id,
      String? aId,
      String? bId,
      FixtureProgressionRule? winnerRule,
      FixtureProgressionRule? loserRule,
      String? linkedMatchId,
    }) {
      return ScheduleFixture(
        id: id,
        order: 0,
        teamASource: aId != null ? ScheduleSource.team(aId) : const ScheduleSource.tbd(),
        teamBSource: bId != null ? ScheduleSource.team(bId) : const ScheduleSource.tbd(),
        resolvedTeamAId: aId,
        resolvedTeamBId: bId,
        winnerRule: winnerRule,
        loserRule: loserRule,
        linkedMatchId: linkedMatchId,
        status: aId != null && bId != null ? FixtureStatus.ready : FixtureStatus.pending,
      );
    }

    FixtureProgressionRule rule(String sourceId, String outcome,
            ProgressionDestinationType type,
            {String? fixtureId, String? stageId}) =>
        FixtureProgressionRule(
          sourceFixtureId: sourceId,
          outcome: outcome,
          destinationType: type,
          destinationFixtureId: fixtureId,
          destinationStageId: stageId,
        );

    test('Winner advances to exact next fixture', () {
      final sf1 = _fx(
        id: 'sf1',
        aId: 'team1',
        bId: 'team2',
        linkedMatchId: 'm1',
        winnerRule: rule('sf1', 'winner', ProgressionDestinationType.fixture, fixtureId: 'final'),
      );
      final fin = _fx(id: 'final');
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1, fin]),
      ];

      final updated = engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
      );

      final finalFx = updated[0].fixtures.firstWhere((f) => f.id == 'final');
      expect(finalFx.resolvedTeamAId, 'team1');
      expect(finalFx.status, FixtureStatus.pending); // Waiting for opponent
    });

    test('Loser advances to exact lower bracket fixture', () {
      final sf1 = _fx(
        id: 'sf1',
        aId: 'team1',
        bId: 'team2',
        linkedMatchId: 'm1',
        loserRule: rule('sf1', 'loser', ProgressionDestinationType.fixture, fixtureId: 'lower'),
      );
      final lower = _fx(id: 'lower');
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1, lower]),
      ];

      final updated = engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
      );

      final lowerFx = updated[0].fixtures.firstWhere((f) => f.id == 'lower');
      expect(lowerFx.resolvedTeamAId, 'team2');
    });

    test('Fixture becomes Ready when second team arrives', () {
      final fin = _fx(id: 'final', aId: 'team1'); // Already has one team
      final sf2 = _fx(
        id: 'sf2',
        aId: 'team3',
        bId: 'team4',
        linkedMatchId: 'm2',
        winnerRule: rule('sf2', 'winner', ProgressionDestinationType.fixture, fixtureId: 'final'),
      );
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf2, fin]),
      ];

      final updated = engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm2', winnerTeamId: 'team3', loserTeamId: 'team4'),
      );

      final finalFx = updated[0].fixtures.firstWhere((f) => f.id == 'final');
      expect(finalFx.resolvedTeamAId, 'team1');
      expect(finalFx.resolvedTeamBId, 'team3');
      expect(finalFx.status, FixtureStatus.ready);
    });

    test('Winner marked as Champion', () {
      bool championCalled = false;
      final sf1 = _fx(
        id: 'sf1',
        aId: 'team1',
        bId: 'team2',
        linkedMatchId: 'm1',
        winnerRule: rule('sf1', 'winner', ProgressionDestinationType.champion),
      );
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1]),
      ];

      engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
        onTeamUpdate: (id, {eliminated, qualified, champion}) {
            if (id == 'team1' && champion == true) championCalled = true;
        },
      );

      expect(championCalled, isTrue);
    });

    test('Loser marked as Eliminated', () {
      bool eliminatedCalled = false;
      final sf1 = _fx(
        id: 'sf1',
        aId: 'team1',
        bId: 'team2',
        linkedMatchId: 'm1',
        loserRule: rule('sf1', 'loser', ProgressionDestinationType.eliminated),
      );
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1]),
      ];

      engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
        onTeamUpdate: (id, {eliminated, qualified, champion}) {
            if (id == 'team2' && eliminated == true) eliminatedCalled = true;
        },
      );

      expect(eliminatedCalled, isTrue);
    });

    test('Winner marked as Qualified', () {
      bool qualifiedCalled = false;
      final sf1 = _fx(
        id: 'sf1',
        aId: 'team1',
        bId: 'team2',
        linkedMatchId: 'm1',
        winnerRule: rule('sf1', 'winner', ProgressionDestinationType.qualify),
      );
      
      final stages = [
        ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1]),
      ];

      engine.processMatchResult(
        stages,
        const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
        onTeamUpdate: (id, {eliminated, qualified, champion}) {
            if (id == 'team1' && qualified == true) qualifiedCalled = true;
        },
      );

      expect(qualifiedCalled, isTrue);
    });

    test('Legacy fallback works when no rules are present', () {
        // Mocking legacy consumer by using TournamentProgressionResolver logic
        // This is tricky without a full repository, but we can test the Resolver's _fateFor fallback.
        final sf1 = _fx(id: 'sf1', aId: 'team1', bId: 'team2', linkedMatchId: 'm1');
        final fin = ScheduleFixture(
            id: 'final',
            order: 1,
            teamASource: ScheduleSource.matchResult('sf1', 'winner'),
            teamBSource: const ScheduleSource.tbd(),
        );
        
        final stages = [
            ScheduleStage(id: 's1', name: 'S1', order: 0, type: ScheduleStageType.knockout, fixtures: [sf1, fin]),
        ];

        final updated = engine.processMatchResult(
            stages,
            const MatchResultOutcome(matchId: 'm1', winnerTeamId: 'team1', loserTeamId: 'team2'),
        );

        // processMatchResult uses _applyFate which only handles nextFixture/nextStage.
        // Legacy fallback in _fateFor handles nextFixture.
        final finalFx = updated[0].fixtures.firstWhere((f) => f.id == 'final');
        expect(finalFx.resolvedTeamAId, 'team1');
    });
  });
}
