// lib/data/engines/tournament_progression_engine.dart
// Handles processing of tournament progression and stage transitions

import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/models/scorer/tournament_progression.dart';

class TournamentProgressionEngine {
  /// Processes a completed match and returns an updated list of stages
  /// with the progressed teams.
  List<ScheduleStage> processMatchResult(
    List<ScheduleStage> currentStages,
    MatchResultOutcome outcome, {
    void Function(String teamId, {bool? eliminated, bool? qualified, bool? champion})? onTeamUpdate,
  }) {
    var stages = List<ScheduleStage>.from(currentStages);
    final resolver = TournamentProgressionResolver(stages);

    // 1. Identify the source fixture
    final sourceFixture = resolver.findFixtureByMatchId(outcome.matchId) ?? 
                         resolver.findFixtureByTeams(outcome.matchId, outcome.winnerTeamId, outcome.loserTeamId);
    
    if (sourceFixture == null) return stages;

    // 2. Mark source fixture completed and persist winner
    stages = _updateFixture(stages, sourceFixture.id, (fx) {
      return fx.copyWith(
        status: FixtureStatus.completed,
        winnerTeamId: outcome.winnerTeamId,
      );
    });

    // 3. Resolve fates using the updated resolver (with the completed fixture)
    final updatedResolver = TournamentProgressionResolver(stages);
    final progression = updatedResolver.resolve(sourceFixture);

    // 4. Apply Winner Fate
    stages = _applyFate(
      stages,
      outcome.winnerTeamId,
      progression.winnerFate,
      onTeamUpdate,
    );

    // 5. Apply Loser Fate
    stages = _applyFate(
      stages,
      outcome.loserTeamId,
      progression.loserFate,
      onTeamUpdate,
    );

    return stages;
  }

  List<ScheduleStage> _updateFixture(
    List<ScheduleStage> stages,
    String fixtureId,
    ScheduleFixture Function(ScheduleFixture) update,
  ) {
    return stages.map((s) {
      final idx = s.fixtures.indexWhere((f) => f.id == fixtureId);
      if (idx < 0) return s;
      final fixtures = List<ScheduleFixture>.from(s.fixtures);
      fixtures[idx] = update(fixtures[idx]);
      return s.copyWith(fixtures: fixtures);
    }).toList();
  }

  List<ScheduleStage> _applyFate(
    List<ScheduleStage> stages,
    String teamId,
    TeamFate fate,
    void Function(String teamId, {bool? eliminated, bool? qualified, bool? champion})? onTeamUpdate,
  ) {
    if (fate.champion) {
      onTeamUpdate?.call(teamId, champion: true);
    }
    if (fate.isEliminated) {
      onTeamUpdate?.call(teamId, eliminated: true);
    }
    if (fate.qualify) {
      onTeamUpdate?.call(teamId, qualified: true);
    }

    if (fate.nextFixture != null) {
      // Routing to exact fixture
      return _updateFixture(stages, fate.nextFixture!.id, (fx) {
        if (fx.resolvedTeamAId == teamId || fx.resolvedTeamBId == teamId) {
          return fx; // Already there
        }
        final nextA = fx.resolvedTeamAId;
        final updated = nextA == null
            ? fx.copyWith(resolvedTeamAId: teamId)
            : fx.copyWith(resolvedTeamBId: teamId);
        
        // If both slots filled, mark Ready; otherwise pending (Waiting for Opponent)
        if (updated.resolvedTeamAId != null && updated.resolvedTeamBId != null) {
          return updated.copyWith(status: FixtureStatus.ready);
        }
        return updated.copyWith(status: FixtureStatus.pending);
      });
    } else if (fate.nextStage != null) {
      // Routing to first available fixture in stage
      final stage = stages.firstWhere((s) => s.id == fate.nextStage!.id);
      final targetFx = stage.fixtures.firstWhere(
        (f) => (f.resolvedTeamAId == null || f.resolvedTeamBId == null) && f.status != FixtureStatus.completed,
        orElse: () => stage.fixtures.first,
      );
      return _updateFixture(stages, targetFx.id, (fx) {
        if (fx.resolvedTeamAId == teamId || fx.resolvedTeamBId == teamId) {
          return fx;
        }
        final nextA = fx.resolvedTeamAId;
        final updated = nextA == null
            ? fx.copyWith(resolvedTeamAId: teamId)
            : fx.copyWith(resolvedTeamBId: teamId);
        if (updated.resolvedTeamAId != null && updated.resolvedTeamBId != null) {
          return updated.copyWith(status: FixtureStatus.ready);
        }
        return updated.copyWith(status: FixtureStatus.pending);
      });
    }
    return stages;
  }
}

/// What happens to a team after its fixture is completed.
class TeamFate {
  final StageProgressionAction action;
  final ScheduleFixture? nextFixture;
  final ScheduleStage? nextStage;

  /// True when the downstream match already has both teams.
  final bool nextFixtureReady;

  /// True when the downstream match exists but still needs an opponent.
  final bool nextFixtureWaiting;

  /// True when the team is crowned champion (configured winner destination,
  /// no further match) — independent of any stage config assumption.
  final bool champion;

  /// True when the destination is an explicit "waiting" placeholder: the team
  /// stays in the tournament awaiting a next round / opponent.
  final bool waiting;

  /// True when the destination is an explicit "qualify" outcome.
  final bool qualify;

  const TeamFate({
    this.action = StageProgressionAction.none,
    this.nextFixture,
    this.nextStage,
    this.nextFixtureReady = false,
    this.nextFixtureWaiting = false,
    this.champion = false,
    this.waiting = false,
    this.qualify = false,
  });

  bool get isEliminated =>
      action == StageProgressionAction.eliminate &&
      nextFixture == null &&
      nextStage == null &&
      !champion &&
      !waiting &&
      !qualify;
}

/// Bracket position of a single fixture: who won/lost, and where each side goes.
class FixtureProgression {
  final ScheduleFixture fixture;
  final ScheduleStage stage;
  final String? winnerTeamId;
  final String? loserTeamId;
  final TeamFate winnerFate;
  final TeamFate loserFate;

  /// A pending/ready fixture with exactly one resolved side is queued behind
  /// another match that has not finished yet.
  final bool waitingForOpponent;

  const FixtureProgression({
    required this.fixture,
    required this.stage,
    this.winnerTeamId,
    this.loserTeamId,
    required this.winnerFate,
    required this.loserFate,
    this.waitingForOpponent = false,
  });
}

/// Analyzes the stage/fixture graph to answer "who goes where next".
class TournamentProgressionResolver {
  final List<ScheduleStage> stages;

  TournamentProgressionResolver(this.stages);

  late final Map<String, ScheduleFixture> _fixtureById = {
    for (final s in stages)
      for (final f in s.fixtures) f.id: f,
  };

  late final Map<String, ScheduleStage> _stageByFixtureId = {
    for (final s in stages)
      for (final f in s.fixtures) f.id: s,
  };

  late final Map<String, List<({ScheduleFixture fixture, ScheduleStage stage, String outcome})>> _consumers =
      _buildConsumers();

  Map<String, List<({ScheduleFixture fixture, ScheduleStage stage, String outcome})>> _buildConsumers() {
    final map = <String, List<({ScheduleFixture fixture, ScheduleStage stage, String outcome})>>{};
    for (final s in stages) {
      for (final f in s.fixtures) {
        void add(Source src) {
          if (src.type == FixtureSourceType.matchResult &&
              src.fixtureId != null) {
            map
                .putIfAbsent(src.fixtureId!, () => [])
                .add((fixture: f, stage: s, outcome: src.outcome ?? 'winner'));
          }
        }

        add(f.teamASource);
        add(f.teamBSource);
      }
    }
    return map;
  }

  ScheduleFixture? findFixture(String id) => _fixtureById[id];

  ScheduleFixture? findFixtureByMatchId(String matchId) {
    for (final s in stages) {
      for (final f in s.fixtures) {
        if (f.linkedMatchId == matchId) return f;
      }
    }
    return null;
  }

  ScheduleFixture? findFixtureByTeams(String matchId, String teamA, String teamB) {
    for (final s in stages) {
      for (final f in s.fixtures) {
        final a = f.resolvedTeamAId;
        final b = f.resolvedTeamBId;
        if ((a == teamA && b == teamB) || (a == teamB && b == teamA)) {
          return f;
        }
      }
    }
    return null;
  }

  List<FixtureProgression> resolveAll() => [
        for (final s in stages)
          for (final f in s.fixtures) resolve(f),
      ];

  FixtureProgression resolve(ScheduleFixture fx) {
    final stage = _stageByFixtureId[fx.id];
    if (stage == null) {
      return FixtureProgression(
        fixture: fx,
        stage: const ScheduleStage(
            id: '',
            name: '',
            order: 0,
            type: ScheduleStageType.custom,
            fixtures: []),
        winnerFate: const TeamFate(),
        loserFate: const TeamFate(),
      );
    }
    final winner = _winnerOf(fx);
    final loser = winner == null
        ? null
        : (winner == fx.resolvedTeamAId ? fx.resolvedTeamBId : fx.resolvedTeamAId);
    final hasA = fx.resolvedTeamAId != null;
    final hasB = fx.resolvedTeamBId != null;
    final waitingForOpponent = !fx.isCompleted &&
        fx.status != FixtureStatus.live && hasA != hasB;
    return FixtureProgression(
      fixture: fx,
      stage: stage,
      winnerTeamId: winner,
      loserTeamId: loser,
      winnerFate: _fateFor(fx, stage, 'winner'),
      loserFate: _fateFor(fx, stage, 'loser'),
      waitingForOpponent: waitingForOpponent,
    );
  }

  String? _winnerOf(ScheduleFixture fx) {
    if (fx.winnerTeamId != null) return fx.winnerTeamId;
    if (fx.status != FixtureStatus.completed) return null;
    // Fallback inference
    for (final c in _consumers[fx.id] ?? const []) {
      if (c.outcome != 'winner') continue;
      final ra = c.fixture.resolvedTeamAId;
      final rb = c.fixture.resolvedTeamBId;
      if (fx.resolvedTeamAId != null &&
          (ra == fx.resolvedTeamAId || rb == fx.resolvedTeamAId)) {
        return fx.resolvedTeamAId;
      }
      if (fx.resolvedTeamBId != null &&
          (ra == fx.resolvedTeamBId || rb == fx.resolvedTeamBId)) {
        return fx.resolvedTeamBId;
      }
    }
    return null;
  }

  TeamFate _fateFor(ScheduleFixture fx, ScheduleStage stage, String outcome) {
    final rule =
        outcome == 'winner' ? fx.winnerRule : fx.loserRule;

    // 1. Creator-configured per-fixture rule takes absolute priority (Push Model).
    if (rule != null) {
      return _fateFromRule(fx, rule);
    }

    // 2. Legacy inference (Pull Model) — fallback for older schedules.
    final action = outcome == 'winner'
        ? stage.config.winnerAction
        : stage.config.loserAction;
    ScheduleFixture? next;
    ScheduleStage? nextStage;
    if (outcome == 'winner') {
      final explicitId = stage.config.nextMatchByFixtureId[fx.id];
      if (explicitId != null && _fixtureById.containsKey(explicitId)) {
        next = _fixtureById[explicitId];
        nextStage = _stageByFixtureId[explicitId];
      }
    }
    if (next == null) {
      for (final c in _consumers[fx.id] ?? const []) {
        if (c.outcome != outcome) continue;
        next = c.fixture;
        nextStage = c.stage;
        break;
      }
    }
    final ready = next != null &&
        next.resolvedTeamAId != null &&
        next.resolvedTeamBId != null;
    return TeamFate(
      action: action,
      nextFixture: next,
      nextStage: nextStage,
      nextFixtureReady: ready,
      nextFixtureWaiting: next != null && !ready,
      champion: false,
    );
  }

  TeamFate _fateFromRule(ScheduleFixture fx, FixtureProgressionRule rule) {
    switch (rule.destinationType) {
      case ProgressionDestinationType.champion:
        return const TeamFate(
          action: StageProgressionAction.advance,
          champion: true,
        );
      case ProgressionDestinationType.eliminated:
        return const TeamFate(action: StageProgressionAction.eliminate);
      case ProgressionDestinationType.waiting:
        return const TeamFate(
          action: StageProgressionAction.advance,
          waiting: true,
        );
      case ProgressionDestinationType.qualify:
        return const TeamFate(
          action: StageProgressionAction.advance,
          qualify: true,
        );
      case ProgressionDestinationType.fixture:
        final next = rule.destinationFixtureId == null
            ? null
            : _fixtureById[rule.destinationFixtureId];
        if (next == null) {
          return const TeamFate(action: StageProgressionAction.advance);
        }
        final ready = next.resolvedTeamAId != null &&
            next.resolvedTeamBId != null;
        return TeamFate(
          action: StageProgressionAction.advance,
          nextFixture: next,
          nextStage: _stageByFixtureId[next.id],
          nextFixtureReady: ready,
          nextFixtureWaiting: !ready,
        );
      case ProgressionDestinationType.stage:
        final nextStage = rule.destinationStageId == null
            ? null
            : stages.where((s) => s.id == rule.destinationStageId).firstOrNull;
        if (nextStage == null) {
          return const TeamFate(action: StageProgressionAction.advance);
        }
        // Deterministic stage routing: find first fixture with an empty slot
        final next = nextStage.fixtures.firstWhere(
            (f) => (f.resolvedTeamAId == null || f.resolvedTeamBId == null) && f.status != FixtureStatus.completed,
            orElse: () => nextStage.fixtures.first);
        final ready = next.resolvedTeamAId != null &&
            next.resolvedTeamBId != null;
        return TeamFate(
          action: StageProgressionAction.advance,
          nextFixture: next,
          nextStage: nextStage,
          nextFixtureReady: ready,
          nextFixtureWaiting: !ready,
        );
      case ProgressionDestinationType.lowerBracket:
        ScheduleFixture? next;
        ScheduleStage? nextStage;
        if (rule.destinationFixtureId != null &&
            _fixtureById.containsKey(rule.destinationFixtureId)) {
          next = _fixtureById[rule.destinationFixtureId];
          nextStage = _stageByFixtureId[rule.destinationFixtureId!];
        } else if (rule.destinationStageId != null) {
          nextStage =
              stages.where((s) => s.id == rule.destinationStageId).firstOrNull;
          if (nextStage != null) {
            next = nextStage.fixtures.firstWhere(
                (f) =>
                    (f.resolvedTeamAId == null || f.resolvedTeamBId == null) &&
                    f.status != FixtureStatus.completed,
                orElse: () => nextStage!.fixtures.first);
          }
        } else {
          nextStage = stages
              .where((s) =>
                  s.name.toLowerCase().contains('lower') ||
                  s.config.loserAction == StageProgressionAction.lowerBracket)
              .firstOrNull;
          if (nextStage != null) {
            next = nextStage.fixtures.firstWhere(
                (f) =>
                    (f.resolvedTeamAId == null || f.resolvedTeamBId == null) &&
                    f.status != FixtureStatus.completed,
                orElse: () => nextStage!.fixtures.first);
          }
        }
        if (next == null && nextStage == null) {
          return const TeamFate(
            action: StageProgressionAction.lowerBracket,
            waiting: true,
          );
        }
        final ready = next != null &&
            next.resolvedTeamAId != null &&
            next.resolvedTeamBId != null;
        return TeamFate(
          action: StageProgressionAction.lowerBracket,
          nextFixture: next,
          nextStage: nextStage,
          nextFixtureReady: ready,
          nextFixtureWaiting: next != null && !ready,
        );
    }
  }
}
