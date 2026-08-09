// lib/data/models/match_notification_prefs.dart
// Per-match notification preferences for a spectator.
//
// Persisted to Firestore at `users/{userId}/matchAlerts/{matchId}`. The
// client-side alert listener (see core/services/match_alert_service.dart) reads
// these to know which matches to watch and which events to notify. `enabled` is
// the master switch; the event toggles (`matchStart` / `firstInningsStart` /
// `secondInningsStart` / `wicket` / `matchComplete`) are the per-event options
// the user can turn on independently for each match.

class MatchNotificationPrefs {
  final String matchId;
  final bool enabled;
  final bool matchStart;
  final bool firstInningsStart;
  final bool secondInningsStart;
  final bool wicket;
  final bool matchComplete;

  const MatchNotificationPrefs({
    required this.matchId,
    this.enabled = false,
    this.matchStart = false,
    this.firstInningsStart = false,
    this.secondInningsStart = false,
    this.wicket = false,
    this.matchComplete = false,
  });

  MatchNotificationPrefs copyWith({
    bool? enabled,
    bool? matchStart,
    bool? firstInningsStart,
    bool? secondInningsStart,
    bool? wicket,
    bool? matchComplete,
  }) =>
      MatchNotificationPrefs(
        matchId: matchId,
        enabled: enabled ?? this.enabled,
        matchStart: matchStart ?? this.matchStart,
        firstInningsStart: firstInningsStart ?? this.firstInningsStart,
        secondInningsStart: secondInningsStart ?? this.secondInningsStart,
        wicket: wicket ?? this.wicket,
        matchComplete: matchComplete ?? this.matchComplete,
      );

  /// Whether at least one event type is subscribed (used by the sender).
  bool get anyEnabled =>
      enabled &&
      (matchStart ||
          firstInningsStart ||
          secondInningsStart ||
          wicket ||
          matchComplete);

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'enabled': enabled,
        'matchStart': matchStart,
        'firstInningsStart': firstInningsStart,
        'secondInningsStart': secondInningsStart,
        'wicket': wicket,
        'matchComplete': matchComplete,
      };

  factory MatchNotificationPrefs.fromJson(Map<String, dynamic> json) =>
      MatchNotificationPrefs(
        matchId: json['matchId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        matchStart: json['matchStart'] as bool? ?? false,
        firstInningsStart: json['firstInningsStart'] as bool? ?? false,
        secondInningsStart: json['secondInningsStart'] as bool? ?? false,
        wicket: json['wicket'] as bool? ?? false,
        matchComplete: json['matchComplete'] as bool? ?? false,
      );
}
