// lib/data/models/tournament_notification_prefs.dart
// Tournament-wide notification preferences for a spectator.
//
// Persisted to Firestore at `users/{userId}/tournamentAlerts/{tournamentId}`.
// The client-side alert listener (see core/services/match_alert_service.dart)
// resolves the tournament's matches and applies these prefs to every alert that
// falls in the tournament, so the user can follow an entire tournament with one
// set of toggles instead of subscribing to each match individually.

import 'package:sportyapp/data/models/match_notification_prefs.dart';

class TournamentNotificationPrefs {
  final String tournamentId;
  final bool enabled;
  final bool matchStart;
  final bool firstInningsStart;
  final bool secondInningsStart;
  final bool wicket;
  final bool matchComplete;

  const TournamentNotificationPrefs({
    required this.tournamentId,
    this.enabled = false,
    this.matchStart = false,
    this.firstInningsStart = false,
    this.secondInningsStart = false,
    this.wicket = false,
    this.matchComplete = false,
  });

  TournamentNotificationPrefs copyWith({
    bool? enabled,
    bool? matchStart,
    bool? firstInningsStart,
    bool? secondInningsStart,
    bool? wicket,
    bool? matchComplete,
  }) =>
      TournamentNotificationPrefs(
        tournamentId: tournamentId,
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

  /// Views the tournament subscription as per-match prefs for [matchId] so the
  /// alert listener can treat tournament matches uniformly with direct ones.
  MatchNotificationPrefs toMatchPrefs(String matchId) => MatchNotificationPrefs(
        matchId: matchId,
        enabled: enabled,
        matchStart: matchStart,
        firstInningsStart: firstInningsStart,
        secondInningsStart: secondInningsStart,
        wicket: wicket,
        matchComplete: matchComplete,
      );

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'enabled': enabled,
        'matchStart': matchStart,
        'firstInningsStart': firstInningsStart,
        'secondInningsStart': secondInningsStart,
        'wicket': wicket,
        'matchComplete': matchComplete,
      };

  factory TournamentNotificationPrefs.fromJson(Map<String, dynamic> json) =>
      TournamentNotificationPrefs(
        tournamentId: json['tournamentId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        matchStart: json['matchStart'] as bool? ?? false,
        firstInningsStart: json['firstInningsStart'] as bool? ?? false,
        secondInningsStart: json['secondInningsStart'] as bool? ?? false,
        wicket: json['wicket'] as bool? ?? false,
        matchComplete: json['matchComplete'] as bool? ?? false,
      );
}
