// lib/data/models/scorer/scorer_schedule.dart
// Tournament schedule domain models: stages, fixtures and fixture sources.

typedef Source = ScheduleSource;

/// Where a fixture's side (Team A / Team B) comes from.
enum FixtureSourceType { team, matchResult, tablePosition, tbd }

/// Where a fixture's team comes from:
///  - team:         a fixed team
///  - matchResult:  winner/loser of another fixture
///  - tablePosition: Nth place in a stage's points table
///  - tbd:          scorer fills it in later
class ScheduleSource {
  final FixtureSourceType type;
  final String? teamId;
  final String? fixtureId;
  final String? outcome; // 'winner' | 'loser' (for matchResult)
  final String? stageId; // (for tablePosition)
  final int? position; // (for tablePosition, 1-based)

  const ScheduleSource({
    required this.type,
    this.teamId,
    this.fixtureId,
    this.outcome,
    this.stageId,
    this.position,
  });

  const ScheduleSource.team(String id)
      : type = FixtureSourceType.team,
        teamId = id,
        fixtureId = null,
        outcome = null,
        stageId = null,
        position = null;

  const ScheduleSource.tbd()
      : type = FixtureSourceType.tbd,
        teamId = null,
        fixtureId = null,
        outcome = null,
        stageId = null,
        position = null;

  factory ScheduleSource.matchResult(String fixtureId, String outcome) =>
      ScheduleSource(
        type: FixtureSourceType.matchResult,
        fixtureId: fixtureId,
        outcome: outcome,
      );

  factory ScheduleSource.tablePosition(String stageId, int position) =>
      ScheduleSource(
        type: FixtureSourceType.tablePosition,
        stageId: stageId,
        position: position,
      );

  bool get isResolved => type == FixtureSourceType.team || type == FixtureSourceType.tbd;

  ScheduleSource copyWith({
    FixtureSourceType? type,
    String? teamId,
    String? fixtureId,
    String? outcome,
    String? stageId,
    int? position,
  }) {
    return ScheduleSource(
      type: type ?? this.type,
      teamId: teamId ?? this.teamId,
      fixtureId: fixtureId ?? this.fixtureId,
      outcome: outcome ?? this.outcome,
      stageId: stageId ?? this.stageId,
      position: position ?? this.position,
    );
  }
}

enum FixtureStatus { pending, ready, live, completed }

/// Where a fixture's winner or loser is routed once its match completes.
enum ProgressionDestinationType {
  fixture,
  stage,
  lowerBracket,
  waiting,
  qualify,
  champion,
  eliminated
}

/// Per-fixture, creator-configured progression rule: what happens to the
/// winner (or loser) of a [ScheduleFixture] after it completes.
///
/// The destination is resolved by [destinationType]:
///  - fixture:      routed into the empty slot of another fixture
///  - stage:        routed into the first empty fixture of a stage
///  - lowerBracket: routed into a lower bracket fixture or stage
///  - waiting:      stays in the flow, waiting for an opponent / next round
///  - champion:     wins the tournament (no further match)
///  - eliminated:   out of the tournament (no further match)
class FixtureProgressionRule {
  final String sourceFixtureId;
  final String outcome; // 'winner' | 'loser'
  final ProgressionDestinationType destinationType;
  final String? destinationFixtureId;
  final String? destinationStageId;

  const FixtureProgressionRule({
    required this.sourceFixtureId,
    required this.outcome,
    required this.destinationType,
    this.destinationFixtureId,
    this.destinationStageId,
  });

  bool get isLowerBracket =>
      destinationType == ProgressionDestinationType.lowerBracket;
  bool get isWaiting => destinationType == ProgressionDestinationType.waiting;
  bool get isQualify => destinationType == ProgressionDestinationType.qualify;
  bool get isEliminated =>
      destinationType == ProgressionDestinationType.eliminated;
  bool get isChampion =>
      destinationType == ProgressionDestinationType.champion;
  bool get isExplicit =>
      destinationType == ProgressionDestinationType.fixture ||
      destinationType == ProgressionDestinationType.stage ||
      destinationType == ProgressionDestinationType.lowerBracket;

  FixtureProgressionRule copyWith({
    String? outcome,
    ProgressionDestinationType? destinationType,
    String? destinationFixtureId,
    String? destinationStageId,
  }) {
    return FixtureProgressionRule(
      sourceFixtureId: sourceFixtureId,
      outcome: outcome ?? this.outcome,
      destinationType: destinationType ?? this.destinationType,
      destinationFixtureId:
          destinationFixtureId ?? this.destinationFixtureId,
      destinationStageId: destinationStageId ?? this.destinationStageId,
    );
  }
}

class ScheduleFixture {
  final String id;
  final int order;
  final Source teamASource;
  final Source teamBSource;
  final String? resolvedTeamAId;
  final String? resolvedTeamBId;

  /// Winning team id once the fixture is [FixtureStatus.completed].
  final String? winnerTeamId;
  final DateTime? scheduledDateTime;
  final String? venue;
  final String? linkedMatchId;
  final FixtureStatus status;

  /// Creator-configured routing for this fixture's winner/loser. When present,
  /// these rules take priority over stage config inference.
  final FixtureProgressionRule? winnerRule;
  final FixtureProgressionRule? loserRule;

  const ScheduleFixture({
    required this.id,
    required this.order,
    required this.teamASource,
    required this.teamBSource,
    this.resolvedTeamAId,
    this.resolvedTeamBId,
    this.winnerTeamId,
    this.scheduledDateTime,
    this.venue,
    this.linkedMatchId,
    this.status = FixtureStatus.pending,
    this.winnerRule,
    this.loserRule,
  });

  bool get isReady => status == FixtureStatus.ready;
  bool get isLive => status == FixtureStatus.live;
  bool get isCompleted => status == FixtureStatus.completed;

  ScheduleFixture copyWith({
    int? order,
    Source? teamASource,
    Source? teamBSource,
    String? resolvedTeamAId,
    String? resolvedTeamBId,
    String? winnerTeamId,
    DateTime? scheduledDateTime,
    String? venue,
    String? linkedMatchId,
    FixtureStatus? status,
    FixtureProgressionRule? winnerRule,
    FixtureProgressionRule? loserRule,
    bool clearResolved = false,
    bool clearWinner = false,
    bool clearRules = false,
  }) {
    return ScheduleFixture(
      id: id,
      order: order ?? this.order,
      teamASource: teamASource ?? this.teamASource,
      teamBSource: teamBSource ?? this.teamBSource,
      resolvedTeamAId: clearResolved ? null : (resolvedTeamAId ?? this.resolvedTeamAId),
      resolvedTeamBId: clearResolved ? null : (resolvedTeamBId ?? this.resolvedTeamBId),
      winnerTeamId: clearWinner ? null : (winnerTeamId ?? this.winnerTeamId),
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      venue: venue ?? this.venue,
      linkedMatchId: linkedMatchId ?? this.linkedMatchId,
      status: status ?? this.status,
      winnerRule: clearRules ? null : (winnerRule ?? this.winnerRule),
      loserRule: clearRules ? null : (loserRule ?? this.loserRule),
    );
  }
}

enum ScheduleStageType { roundRobin, knockout, custom }

enum StageQualificationRule { topN, all, none }

enum StageProgressionAction {
  advance,
  eliminate,
  lowerBracket,
  repechage,
  thirdPlace,
  stayActive,
  runnerUp,
  none,
}

class StageConfiguration {
  final String? nextStageId;
  final String? previousStageId; // Added for dependency engine
  final String? championStageId; // Added for winner tracking
  final String? runnerUpStageId; // Added for runner up tracking
  final StageQualificationRule qualificationRule;
  final int qualificationCount;
  final StageProgressionAction winnerAction;
  final StageProgressionAction loserAction;
  final bool autoCreateNextMatch;
  final bool autoPairTeams; // Added for seeding/random pairing
  final bool waitingForOpponent;
  final Map<String, String> nextMatchByFixtureId;
  
  // Rules (Phase 1 added requirements)
  final String? tieRule;
  final bool hasSuperOver;
  final bool hasWalkover;
  final bool hasAbandoned;
  final bool hasForfeit;

  const StageConfiguration({
    this.nextStageId,
    this.previousStageId,
    this.championStageId,
    this.runnerUpStageId,
    this.qualificationRule = StageQualificationRule.none,
    this.qualificationCount = 0,
    this.winnerAction = StageProgressionAction.advance,
    this.loserAction = StageProgressionAction.eliminate,
    this.autoCreateNextMatch = false,
    this.autoPairTeams = false,
    this.waitingForOpponent = true,
    this.nextMatchByFixtureId = const {},
    this.tieRule,
    this.hasSuperOver = true,
    this.hasWalkover = true,
    this.hasAbandoned = true,
    this.hasForfeit = true,
  });
}

class ScheduleStage {
  final String id;
  final String name;
  final int order;
  final ScheduleStageType type;
  final List<ScheduleFixture> fixtures;
  final StageConfiguration config;

  const ScheduleStage({
    required this.id,
    required this.name,
    required this.order,
    required this.type,
    required this.fixtures,
    this.config = const StageConfiguration(),
  });

  ScheduleStage copyWith({
    String? name,
    int? order,
    ScheduleStageType? type,
    List<ScheduleFixture>? fixtures,
    StageConfiguration? config,
  }) {
    return ScheduleStage(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      type: type ?? this.type,
      fixtures: fixtures ?? this.fixtures,
      config: config ?? this.config,
    );
  }
}