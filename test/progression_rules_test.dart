// test/progression_rules_test.dart
// Verifies the creator-configured per-fixture progression rules:
//  - winner/loser destinations are resolved by the shared engine (single source
//    of truth) and can route into a specific fixture or stage,
//  - a completed source auto-fills its destination fixture slot (A then B) and
//    flips it to ready once both sides are present,
//  - a team is eliminated ONLY when its configured loser destination is
//    `eliminated` (a lower-match destination is NOT elimination),
//  - a team is champion ONLY when its winner destination is `champion` (no
//    dependency on a stage being named/positioned as the final).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportyapp/data/engines/tournament_progression_engine.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule_serializers.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

Future<ScorerRepository> _seedRepo(List<ScheduleStage> stages) async {
  final repo = ScorerRepository(null);
  await repo.saveTournament(ScorerTournament(
    id: 't1',
    name: 'Rules Cup',
    ownerId: 'owner',
    format: MatchFormat.t20,
    customOvers: 20,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 2, 1),
    venue: 'Ground',
    numTeams: 5,
    teamIds: const ['team1', 'team2', 'team3', 'team4', 'team5'],
    pointsRules: const PointsRules(),
  ));
  for (final t in const [
    ('team1', 'A'),
    ('team2', 'B'),
    ('team3', 'C'),
    ('team4', 'D'),
    ('team5', 'E'),
  ]) {
    await repo.saveTeam(ScorerTeam(
      id: t.$1,
      name: t.$2,
      shortCode: t.$1.substring(4),
      tournamentId: 't1',
      playerIds: const [],
    ));
  }
  await repo.saveSchedule('t1', stages);
  return repo;
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

ScheduleFixture _readyFixture({
  required String id,
  required int order,
  String? aId,
  String? bId,
  FixtureProgressionRule? winnerRule,
  FixtureProgressionRule? loserRule,
}) {
  return ScheduleFixture(
    id: id,
    order: order,
    teamASource: aId == null
        ? const ScheduleSource.tbd()
        : ScheduleSource.team(aId),
    teamBSource: bId == null
        ? const ScheduleSource.tbd()
        : ScheduleSource.team(bId),
    resolvedTeamAId: aId,
    resolvedTeamBId: bId,
    winnerRule: winnerRule,
    loserRule: loserRule,
    status: aId != null && bId != null
        ? FixtureStatus.ready
        : FixtureStatus.pending,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('engine resolves configured rules', () {
    test('champion comes ONLY from a champion winner-rule, not stage config',
        () {
      // Non-final stage: winner rule explicitly says champion.
      final fix = ScheduleFixture(
        id: 'm1',
        order: 1,
        teamASource: const ScheduleSource.team('t1'),
        teamBSource: const ScheduleSource.team('t2'),
        resolvedTeamAId: 't1',
        resolvedTeamBId: 't2',
        winnerTeamId: 't1',
        status: FixtureStatus.completed,
        winnerRule: rule('m1', 'winner', ProgressionDestinationType.champion),
        loserRule: rule('m1', 'loser', ProgressionDestinationType.eliminated),
      );
      final stage = ScheduleStage(
        id: 's1',
        name: 'Round Robin',
        order: 0,
        type: ScheduleStageType.roundRobin,
        fixtures: [fix],
        config: const StageConfiguration(nextStageId: 's2'),
      );

      final prog = TournamentProgressionResolver([stage]).resolve(fix);
      expect(prog.winnerFate.champion, isTrue);
      expect(prog.winnerFate.nextFixture, isNull);
      // Without any rule, and with a nextStageId present, the old heuristic
      // would NOT have crowned a champion — the rule overrides that.
      expect(prog.loserFate.isEliminated, isTrue);
    });

    test('winner rule routes into the configured fixture, even a lower match',
        () {
      final upper = ScheduleFixture(
        id: 'wb',
        order: 1,
        teamASource: const ScheduleSource.team('t1'),
        teamBSource: const ScheduleSource.team('t2'),
        resolvedTeamAId: 't1',
        resolvedTeamBId: 't2',
        winnerTeamId: 't1',
        status: FixtureStatus.completed,
        winnerRule: rule('wb', 'winner', ProgressionDestinationType.fixture,
            fixtureId: 'lb'),
        loserRule: rule('wb', 'loser', ProgressionDestinationType.eliminated),
      );
      final lower = ScheduleFixture(
        id: 'lb',
        order: 2,
        teamASource: const ScheduleSource.tbd(),
        teamBSource: const ScheduleSource.team('t4'),
        resolvedTeamBId: 't4',
      );
      final stage = ScheduleStage(
        id: 's',
        name: 'Bracket',
        order: 0,
        type: ScheduleStageType.knockout,
        fixtures: [upper, lower],
      );

      final prog = TournamentProgressionResolver([stage]).resolve(upper);
      expect(prog.winnerFate.nextFixture?.id, 'lb');
      expect(prog.winnerFate.nextFixtureWaiting, isTrue);
      expect(prog.loserFate.isEliminated, isTrue);
    });

    test('loser with a lower-match destination is NOT eliminated', () {
      final upper = ScheduleFixture(
        id: 'wb',
        order: 1,
        teamASource: const ScheduleSource.team('t1'),
        teamBSource: const ScheduleSource.team('t2'),
        resolvedTeamAId: 't1',
        resolvedTeamBId: 't2',
        winnerTeamId: 't1',
        status: FixtureStatus.completed,
        winnerRule: rule('wb', 'winner', ProgressionDestinationType.fixture,
            fixtureId: 'wf'),
        loserRule: rule('wb', 'loser', ProgressionDestinationType.fixture,
            fixtureId: 'lb'),
      );
      ScheduleFixture finish(FixtureProgressionRule? wr,
              FixtureProgressionRule? lr) =>
          ScheduleFixture(
            id: 'fx',
            order: 3,
            teamASource: const ScheduleSource.team('t5'),
            teamBSource: const ScheduleSource.team('t6'),
            resolvedTeamAId: 't5',
            resolvedTeamBId: 't6',
            winnerRule: wr,
            loserRule: lr,
          );
      final winnersMatch = finish(
          rule('wb', 'winner', ProgressionDestinationType.champion),
          rule('wb', 'winner', ProgressionDestinationType.eliminated));
      final lower = ScheduleFixture(
        id: 'lb',
        order: 2,
        teamASource: const ScheduleSource.tbd(),
        teamBSource: const ScheduleSource.team('t4'),
        resolvedTeamBId: 't4',
      );
      final stage = ScheduleStage(
        id: 's',
        name: 'Bracket',
        order: 0,
        type: ScheduleStageType.knockout,
        fixtures: [upper, lower, winnersMatch],
      );

      final prog = TournamentProgressionResolver([stage]).resolve(upper);
      expect(prog.loserFate.nextFixture?.id, 'lb');
      expect(prog.loserFate.isEliminated, isFalse);
      expect(prog.loserFate.nextFixtureWaiting, isTrue);
    });

    test('waiting destination surfaces nextFixtureWaiting without a match', () {
      final fix = ScheduleFixture(
        id: 'm1',
        order: 1,
        teamASource: const ScheduleSource.team('t1'),
        teamBSource: const ScheduleSource.team('t2'),
        resolvedTeamAId: 't1',
        resolvedTeamBId: 't2',
        winnerTeamId: 't1',
        status: FixtureStatus.completed,
        winnerRule: rule('m1', 'winner', ProgressionDestinationType.waiting),
        loserRule: rule('m1', 'loser', ProgressionDestinationType.eliminated),
      );
      final stage = ScheduleStage(
        id: 's',
        name: 'Group',
        order: 0,
        type: ScheduleStageType.roundRobin,
        fixtures: [fix],
      );

      final prog = TournamentProgressionResolver([stage]).resolve(fix);
      expect(prog.winnerFate.waiting, isTrue);
      expect(prog.winnerFate.nextFixture, isNull);
      expect(prog.winnerFate.nextFixtureWaiting, isFalse);
      expect(prog.winnerFate.isEliminated, isFalse);
    });
  });

  group('repository auto-fills rule destinations', () {
    test('two winners flow into the same destination match (A then B, ready)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final stages = [
        ScheduleStage(
          id: 'semis',
          name: 'Semis',
          order: 0,
          type: ScheduleStageType.knockout,
          fixtures: [
            _readyFixture(
              id: 'sf1',
              order: 1,
              aId: 'team1',
              bId: 'team2',
              winnerRule: rule(
                  'sf1', 'winner', ProgressionDestinationType.fixture,
                  fixtureId: 'fin'),
              loserRule:
                  rule('sf1', 'loser', ProgressionDestinationType.eliminated),
            ),
            _readyFixture(
              id: 'sf2',
              order: 2,
              aId: 'team3',
              bId: 'team4',
              winnerRule: rule(
                  'sf2', 'winner', ProgressionDestinationType.fixture,
                  fixtureId: 'fin'),
              loserRule: rule(
                  'sf2', 'loser', ProgressionDestinationType.fixture,
                  fixtureId: 'lb'),
            ),
          ],
        ),
        ScheduleStage(
          id: 'finals',
          name: 'Finals',
          order: 1,
          type: ScheduleStageType.knockout,
          fixtures: [
            _readyFixture(
              id: 'fin',
              order: 1,
              winnerRule:
                  rule('fin', 'winner', ProgressionDestinationType.champion),
              loserRule:
                  rule('fin', 'loser', ProgressionDestinationType.eliminated),
            ),
            _readyFixture(
              id: 'lb',
              order: 2,
              bId: 'team5',
            ),
          ],
        ),
      ];
      final repo = await _seedRepo(stages);

      // sf1 completes: its winner must seat into the Final's slot A.
      await repo.applyScheduleResult(
        tournamentId: 't1',
        winnerTeamId: 'team1',
        loserTeamId: 'team2',
        linkedFixtureId: 'sf1',
        matchId: 'm1',
      );
      var fin = (await repo.getSchedule('t1'))[1].fixtures.first;
      expect(fin.resolvedTeamAId, 'team1');
      expect(fin.resolvedTeamBId, isNull);
      expect(fin.status, FixtureStatus.pending); // still waiting for opponent

      // sf2 completes: its winner fills slot B → Final becomes ready.
      await repo.applyScheduleResult(
        tournamentId: 't1',
        winnerTeamId: 'team3',
        loserTeamId: 'team4',
        linkedFixtureId: 'sf2',
        matchId: 'm2',
      );
      fin = (await repo.getSchedule('t1'))[1].fixtures.first;
      expect(fin.resolvedTeamAId, 'team1');
      expect(fin.resolvedTeamBId, 'team3');
      expect(fin.status, FixtureStatus.ready);
    });

    test('loser routed to a lower match fills its slot, not eliminated', () async {
      SharedPreferences.setMockInitialValues({});
      final stages = [
        ScheduleStage(
          id: 'semis',
          name: 'Semis',
          order: 0,
          type: ScheduleStageType.knockout,
          fixtures: [
            _readyFixture(
              id: 'sf1',
              order: 1,
              aId: 'team1',
              bId: 'team2',
              winnerRule: rule(
                  'sf1', 'winner', ProgressionDestinationType.fixture,
                  fixtureId: 'fin'),
              loserRule: rule(
                  'sf1', 'loser', ProgressionDestinationType.fixture,
                  fixtureId: 'lb'),
            ),
          ],
        ),
        ScheduleStage(
          id: 'finals',
          name: 'Finals',
          order: 1,
          type: ScheduleStageType.knockout,
          fixtures: [
            _readyFixture(id: 'fin', order: 1, bId: 'team5'),
            _readyFixture(id: 'lb', order: 2),
          ],
        ),
      ];
      final repo = await _seedRepo(stages);

      await repo.applyScheduleResult(
        tournamentId: 't1',
        winnerTeamId: 'team1',
        loserTeamId: 'team2',
        linkedFixtureId: 'sf1',
        matchId: 'm1',
      );

      final finals = (await repo.getSchedule('t1'))[1];
      // Winner goes into the final; loser drops to the lower match.
      expect(finals.fixtures[0].resolvedTeamAId, 'team1');
      expect(finals.fixtures[1].resolvedTeamAId, 'team2');
      // The losing team is NOT flagged eliminated.
      final teams = await repo.getAllTeams();
      expect(teams.firstWhere((t) => t.id == 'team2').isEliminated, isFalse);
    });

    test('a group winner routed to a stage seats into that stage\'s first '
        'open fixture', () async {
      SharedPreferences.setMockInitialValues({});
      final stages = [
        ScheduleStage(
          id: 'group',
          name: 'Group A',
          order: 0,
          type: ScheduleStageType.roundRobin,
          fixtures: [
            _readyFixture(
              id: 'g1',
              order: 1,
              aId: 'team1',
              bId: 'team2',
              winnerRule: rule(
                  'g1', 'winner', ProgressionDestinationType.stage,
                  stageId: 'qf'),
              loserRule:
                  rule('g1', 'loser', ProgressionDestinationType.eliminated),
            ),
          ],
        ),
        ScheduleStage(
          id: 'qf',
          name: 'Quarter Final',
          order: 1,
          type: ScheduleStageType.knockout,
          fixtures: [_readyFixture(id: 'q1', order: 1)],
        ),
      ];
      final repo = await _seedRepo(stages);

      await repo.applyScheduleResult(
        tournamentId: 't1',
        winnerTeamId: 'team1',
        loserTeamId: 'team2',
        linkedFixtureId: 'g1',
        matchId: 'm1',
      );

      final qf = (await repo.getSchedule('t1'))[1];
      expect(qf.fixtures.first.resolvedTeamAId, 'team1');
    });

    test('a team is NOT auto-eliminated when no loser rule exists (legacy '
        'bracket inference still applies)', () async {
      SharedPreferences.setMockInitialValues({});
      // No rules: legacy matchResult wiring. The completed fixture's winner is
      // still picked up; loser elimination comes from the stage's loserAction.
      final stages = [
        ScheduleStage(
          id: 'semis',
          name: 'Semis',
          order: 0,
          type: ScheduleStageType.knockout,
          fixtures: [
            _readyFixture(id: 'sf1', order: 1, aId: 'team1', bId: 'team2'),
          ],
          config: const StageConfiguration(
            nextStageId: 'fin',
            winnerAction: StageProgressionAction.advance,
            loserAction: StageProgressionAction.eliminate,
          ),
        ),
        ScheduleStage(
          id: 'fin',
          name: 'Final',
          order: 1,
          type: ScheduleStageType.knockout,
          fixtures: [
            ScheduleFixture(
              id: 'fin',
              order: 1,
              teamASource: ScheduleSource.matchResult('sf1', 'winner'),
              teamBSource: const ScheduleSource.tbd(),
            ),
          ],
          config: const StageConfiguration(
            winnerAction: StageProgressionAction.advance,
            loserAction: StageProgressionAction.eliminate,
          ),
        ),
      ];
      final repo = await _seedRepo(stages);

      await repo.applyScheduleResult(
        tournamentId: 't1',
        winnerTeamId: 'team1',
        loserTeamId: 'team2',
        linkedFixtureId: 'sf1',
        matchId: 'm1',
      );

      final finals = (await repo.getSchedule('t1'))[1];
      expect(finals.fixtures.first.resolvedTeamAId, 'team1');
    });
  });

  group('serializer round-trips the new rule fields', () {
    test('winner/loser rules survive a JSON round trip', () {
      const fixture = ScheduleFixture(
        id: 'fx1',
        order: 1,
        teamASource: ScheduleSource.team('t1'),
        teamBSource: ScheduleSource.team('t2'),
        resolvedTeamAId: 't1',
        resolvedTeamBId: 't2',
        status: FixtureStatus.pending,
      );
      final withRules = fixture.copyWith(
        winnerRule: FixtureProgressionRule(
          sourceFixtureId: 'fx1',
          outcome: 'winner',
          destinationType: ProgressionDestinationType.fixture,
          destinationFixtureId: 'fx2',
          destinationStageId: 's2',
        ),
        loserRule: FixtureProgressionRule(
          sourceFixtureId: 'fx1',
          outcome: 'loser',
          destinationType: ProgressionDestinationType.eliminated,
        ),
      );

      final json = scheduleFromFixtureToJson(withRules);
      final restored = scheduleFixtureFromJson(json);

      expect(restored.winnerRule, isNotNull);
      expect(restored.winnerRule!.sourceFixtureId, 'fx1');
      expect(restored.winnerRule!.outcome, 'winner');
      expect(restored.winnerRule!.destinationType,
          ProgressionDestinationType.fixture);
      expect(restored.winnerRule!.destinationFixtureId, 'fx2');
      expect(restored.winnerRule!.destinationStageId, 's2');
      expect(restored.loserRule, isNotNull);
      expect(restored.loserRule!.destinationType,
          ProgressionDestinationType.eliminated);
      // Null rules stay null.
      final clean = scheduleFixtureFromJson(scheduleFromFixtureToJson(fixture));
      expect(clean.winnerRule, isNull);
      expect(clean.loserRule, isNull);
    });
  });
}