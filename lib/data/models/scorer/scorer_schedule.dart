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

class ScheduleFixture {
  final String id;
  final int order;
  final Source teamASource;
  final Source teamBSource;
  final String? resolvedTeamAId;
  final String? resolvedTeamBId;
  final DateTime? scheduledDateTime;
  final String? venue;
  final String? linkedMatchId;
  final FixtureStatus status;

  const ScheduleFixture({
    required this.id,
    required this.order,
    required this.teamASource,
    required this.teamBSource,
    this.resolvedTeamAId,
    this.resolvedTeamBId,
    this.scheduledDateTime,
    this.venue,
    this.linkedMatchId,
    this.status = FixtureStatus.pending,
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
    DateTime? scheduledDateTime,
    String? venue,
    String? linkedMatchId,
    FixtureStatus? status,
    bool clearResolved = false,
  }) {
    return ScheduleFixture(
      id: id,
      order: order ?? this.order,
      teamASource: teamASource ?? this.teamASource,
      teamBSource: teamBSource ?? this.teamBSource,
      resolvedTeamAId: clearResolved ? null : (resolvedTeamAId ?? this.resolvedTeamAId),
      resolvedTeamBId: clearResolved ? null : (resolvedTeamBId ?? this.resolvedTeamBId),
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      venue: venue ?? this.venue,
      linkedMatchId: linkedMatchId ?? this.linkedMatchId,
      status: status ?? this.status,
    );
  }
}

enum ScheduleStageType { roundRobin, knockout, custom }

class ScheduleStage {
  final String id;
  final String name;
  final int order;
  final ScheduleStageType type;
  final List<ScheduleFixture> fixtures;

  const ScheduleStage({
    required this.id,
    required this.name,
    required this.order,
    required this.type,
    required this.fixtures,
  });

  ScheduleStage copyWith({
    String? name,
    int? order,
    ScheduleStageType? type,
    List<ScheduleFixture>? fixtures,
  }) {
    return ScheduleStage(
      id: id,
      name: name ?? this.name,
      order: order ?? this.order,
      type: type ?? this.type,
      fixtures: fixtures ?? this.fixtures,
    );
  }
}