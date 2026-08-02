// lib/data/models/scorer/scorer_schedule_serializers.dart
// JSON (de)serialization for tournament schedule (stages & fixtures).

import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';

T _nameToEnum<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  return values.where((v) => v.name == name).firstOrNull ?? fallback;
}

// ─── ScheduleSource ─────────────────────────────────────────────────────────

Map<String, dynamic> scheduleSourceToJson(ScheduleSource s) => {
      'type': s.type.name,
      'teamId': s.teamId,
      'fixtureId': s.fixtureId,
      'outcome': s.outcome,
      'stageId': s.stageId,
      'position': s.position,
    };

ScheduleSource scheduleSourceFromJson(Map<String, dynamic> json) {
  final typename = json['type'] ?? 'tbd';
  final type = _nameToEnum(FixtureSourceType.values, typename as String, FixtureSourceType.tbd);
  switch (type) {
    case FixtureSourceType.team:
      return ScheduleSource.team(json['teamId'] ?? '');
    case FixtureSourceType.matchResult:
      return ScheduleSource.matchResult(
          json['fixtureId'] ?? '', json['outcome'] ?? 'winner');
    case FixtureSourceType.tablePosition:
      return ScheduleSource.tablePosition(
          json['stageId'] ?? '', (json['position'] as num?)?.toInt() ?? 1);
    case FixtureSourceType.tbd:
      return const ScheduleSource.tbd();
  }
}

// ─── Fixture ────────────────────────────────────────────────────────────────

Map<String, dynamic> scheduleFromFixtureToJson(ScheduleFixture f) => {
      'id': f.id,
      'order': f.order,
      'teamASource': scheduleSourceToJson(f.teamASource),
      'teamBSource': scheduleSourceToJson(f.teamBSource),
      'resolvedTeamAId': f.resolvedTeamAId,
      'resolvedTeamBId': f.resolvedTeamBId,
      'scheduledDateTime': f.scheduledDateTime?.toIso8601String(),
      'venue': f.venue,
      'linkedMatchId': f.linkedMatchId,
      'status': f.status.name,
    };

ScheduleFixture scheduleFixtureFromJson(Map<String, dynamic> json) => ScheduleFixture(
      id: json['id'] ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      teamASource: scheduleSourceFromJson(
          json['teamASource'] as Map<String, dynamic>? ?? const {'type': 'tbd'}),
      teamBSource: scheduleSourceFromJson(
          json['teamBSource'] as Map<String, dynamic>? ?? const {'type': 'tbd'}),
      resolvedTeamAId: json['resolvedTeamAId'],
      resolvedTeamBId: json['resolvedTeamBId'],
      scheduledDateTime: json['scheduledDateTime'] == null
          ? null
          : DateTime.tryParse(json['scheduledDateTime'] as String),
      venue: json['venue'],
      linkedMatchId: json['linkedMatchId'],
      status: _nameToEnum(
          FixtureStatus.values, json['status'], FixtureStatus.pending),
    );

// ─── Stage ──────────────────────────────────────────────────────────────────

Map<String, dynamic> scheduleStageToJson(ScheduleStage s) => {
      'id': s.id,
      'name': s.name,
      'order': s.order,
      'type': s.type.name,
      'fixtures': s.fixtures.map(scheduleFromFixtureToJson).toList(),
    };

ScheduleStage scheduleStageFromJson(Map<String, dynamic> json) => ScheduleStage(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      type: _nameToEnum(ScheduleStageType.values, json['type'], ScheduleStageType.custom),
      fixtures: (json['fixtures'] as List? ?? [])
          .map((e) => scheduleFixtureFromJson(e as Map<String, dynamic>))
          .toList(),
    );