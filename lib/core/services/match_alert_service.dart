// lib/core/services/match_alert_service.dart
// Client-side match alert delivery.
//
// Match-start / innings-start / wicket / match-complete alerts are delivered
// entirely from the spectator app — no Cloud Functions, FCM or paid Firebase
// services.
//
// The scorer publishes a compact live payload to the Realtime Database
// (`liveMatches/{matchId}`) on every ball, stamped with a `lastEvent` object:
//   { id: <stable event id>, type: start|ball|wicket|complete|..., ... }
//
// This listener watches the RTDB nodes of every match the signed-in user has
// enabled alerts for (read from Firestore `users/{uid}/matchAlerts`) and, while
// the app is active, shows a local notification with the event-specific custom
// sound when a new start/innings-start/wicket/complete event arrives.
//
// Tournament alerts: the user can instead enable alerts per tournament
// (`users/{uid}/tournamentAlerts`). The listener then watches the Firestore
// `matches` documents of each subscribed tournament, subscribes to the RTDB
// nodes of those (non-completed) matches, and applies the tournament's toggles
// to events for any match that has no direct per-match subscription.
//
// Deduplication:
//   • the FIRST emission received after subscribing establishes the baseline.
//     If it carries an event (subscribed mid-match) that event is remembered,
//     not notified, so events that already happened never fire. If it is empty
//     (subscribed before the match started) the next event — the match start —
//     is a genuinely new event and IS notified;
//   • each event `id` is remembered for the session, so a re-published event
//     (e.g. the scorer restoring a draft) is never notified twice.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/services/notification_service.dart';
import 'package:sportyapp/data/models/match_notification_prefs.dart';
import 'package:sportyapp/data/models/tournament_notification_prefs.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart';

/// Injected by tests to capture notifications without touching the real
/// device notification plugin.
typedef MatchAlertNotify = Future<void> Function({
  required String matchId,
  required String eventType,
  required String title,
  required String body,
});

/// Streams the Firestore `matches` documents (raw maps) of one tournament.
/// Injectable so tests can drive tournament→match resolution without Firebase.
typedef WatchTournamentMatches = Stream<List<Map<String, dynamic>>> Function(
    String tournamentId);

class MatchAlertListener {
  final Ref _ref;
  final MatchAlertNotify? _notify;
  final Stream<Map<String, dynamic>?> Function(String matchId)? _watchLiveMatch;
  final WatchTournamentMatches? _watchTournamentMatches;

  /// matchIds whose first RTDB emission has already established the baseline.
  final Set<String> _baselineDone = {};
  final Set<String> _seenEvents = {};
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _rtdbSubs = {};
  Map<String, MatchNotificationPrefs> _prefs = {};
  Map<String, TournamentNotificationPrefs> _tournamentPrefs = {};
  String? _uid;

  // Tournament → matches resolution.
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>> _tournamentSubs = {};
  final Map<String, String> _matchToTournament = {};
  Set<String> _tournamentMatchIds = <String>{};

  MatchAlertListener(
    this._ref, {
    MatchAlertNotify? notify,
    Stream<Map<String, dynamic>?> Function(String matchId)? watchLiveMatch,
    WatchTournamentMatches? watchTournamentMatches,
  })  : _notify = notify,
        _watchLiveMatch = watchLiveMatch,
        _watchTournamentMatches = watchTournamentMatches {
    _ref.listen(currentUserIdProvider, (_, next) {
      _uid = next;
      _reconcile();
    }, fireImmediately: true);
    _ref.listen(matchAlertsMapProvider, (_, next) {
      _prefs = next.valueOrNull ?? const {};
      _reconcile();
    }, fireImmediately: true);
    _ref.listen(tournamentAlertsMapProvider, (_, next) {
      _tournamentPrefs = next.valueOrNull ?? const {};
      _reconcileTournaments();
      _reconcile();
    }, fireImmediately: true);
  }

  /// Whether the listener currently watches [matchId] (used by tests).
  bool isWatching(String matchId) => _rtdbSubs.containsKey(matchId);

  /// Reconciles the RTDB subscriptions with the current user + prefs
  /// (per-match subscriptions plus every match of subscribed tournaments).
  void _reconcile() {
    if (_uid == null) {
      _stopAll();
      return;
    }
    final desired = <String>{};
    _prefs.forEach((matchId, p) {
      if (p.enabled && p.anyEnabled) {
        desired.add(matchId);
      }
    });
    desired.addAll(_tournamentMatchIds);

    for (final id in _rtdbSubs.keys.toList()) {
      if (!desired.contains(id)) {
        _rtdbSubs.remove(id)?.cancel();
        _baselineDone.remove(id);
      }
    }
    for (final id in desired) {
      if (_rtdbSubs.containsKey(id)) continue;
      final watchLiveMatch = _watchLiveMatch;
      final stream = watchLiveMatch != null
          ? watchLiveMatch(id)
          : _ref.read(realtimeDatabaseProvider).watchLiveMatch(id);
      _rtdbSubs[id] = stream.listen(
        (raw) => _onLiveData(id, raw),
        onError: (_) {
          // RTDB transient error — the stream will recover on its own.
        },
      );
    }
  }

  /// Keeps the Firestore `matches` watch for each subscribed tournament in
  /// sync with the current tournament prefs.
  void _reconcileTournaments() {
    final desired = <String>{};
    _tournamentPrefs.forEach((tId, p) {
      if (p.enabled && p.anyEnabled) {
        desired.add(tId);
      }
    });
    for (final t in _tournamentSubs.keys.toList()) {
      if (!desired.contains(t)) {
        _tournamentSubs.remove(t)?.cancel();
      }
    }
    for (final t in desired) {
      if (_tournamentSubs.containsKey(t)) continue;
      final watch = _watchTournamentMatches;
      final stream = watch != null
          ? watch(t)
          : _ref
              .read(firestoreProvider)
              .collection('matches')
              .where('tournamentId', isEqualTo: t)
              .snapshots()
              .map((snap) => snap.docs.map((d) => d.data()).toList());
      _tournamentSubs[t] = stream.listen(
        (docs) => _onTournamentMatches(t, docs),
        onError: (_) {
          // Firestore transient error — the stream will recover on its own.
        },
      );
    }
  }

  /// Updates the set of tournament matchIds to watch and remembers each
  /// matchId → tournamentId so incoming events can resolve the tournament's
  /// prefs. Completed matches have no live node, so they are skipped.
  void _onTournamentMatches(
      String tournamentId, List<Map<String, dynamic>> docs) {
    final ids = <String>{};
    for (final d in docs) {
      final id = d['id'] as String?;
      if (id == null || id.isEmpty) continue;
      if (d['status'] == 'completed') continue;
      ids.add(id);
      _matchToTournament[id] = tournamentId;
    }
    _tournamentMatchIds = ids;
    _reconcile();
  }

  Future<void> _onLiveData(String matchId, Map<String, dynamic>? raw) async {
    // First emission establishes the baseline (see dedup notes in the header).
    if (!_baselineDone.contains(matchId)) {
      _baselineDone.add(matchId);
      final firstEvent = raw?['lastEvent'];
      if (firstEvent is Map) {
        final eventId = firstEvent['id'];
        if (eventId is String && eventId.isNotEmpty) {
          _seenEvents.add(eventId);
        }
      }
      return;
    }

    if (raw == null) return;
    final lastEvent = raw['lastEvent'];
    if (lastEvent is! Map) return;
    final eventId = lastEvent['id'];
    if (eventId is! String || eventId.isEmpty) return;
    if (!_seenEvents.add(eventId)) return; // already notified for this event

    // Resolve the active subscription: a direct per-match subscription wins;
    // otherwise fall back to the match's tournament subscription.
    MatchNotificationPrefs? prefs = _prefs[matchId];
    if (prefs == null || !prefs.enabled) {
      final tId = _matchToTournament[matchId];
      if (tId != null) {
        final tPrefs = _tournamentPrefs[tId];
        if (tPrefs != null && tPrefs.enabled) {
          prefs = tPrefs.toMatchPrefs(matchId);
        }
      }
    }
    if (prefs == null || !prefs.enabled) return;

    final type = lastEvent['type'];
    final wants = switch (type) {
      'start' => prefs.matchStart,
      'first_innings_start' => prefs.firstInningsStart,
      'second_innings_start' => prefs.secondInningsStart,
      'wicket' => prefs.wicket,
      'complete' => prefs.matchComplete,
      _ => false,
    };
    if (!wants) return;

    final team1 = (raw['team1Name'] as String?) ?? '';
    final team2 = (raw['team2Name'] as String?) ?? '';
    final vs =
        team1.isNotEmpty && team2.isNotEmpty ? '$team1 vs $team2' : 'Match';
    final title = 'CRIXORA';
    final body = switch (type) {
      'start' => '$vs has started',
      'first_innings_start' => '$vs — 1st innings has started',
      'second_innings_start' => '$vs — 2nd innings has started',
      'wicket' => '$vs — Wicket!',
      _ => '$vs — Match completed',
    };

    final notify = _notify;
    if (notify != null) {
      await notify(
        matchId: matchId,
        eventType: type,
        title: title,
        body: body,
      );
      return;
    }

    final svc = NotificationService.instance;
    switch (type) {
      case 'start':
      case 'first_innings_start':
      case 'second_innings_start':
        await svc.showMatchStarted(
          matchId: matchId,
          title: title,
          body: body,
        );
        break;
      case 'wicket':
        await svc.showWicket(
          matchId: matchId,
          title: title,
          body: body,
        );
        break;
      case 'complete':
        await svc.showMatchCompleted(
          matchId: matchId,
          title: title,
          body: body,
        );
        break;
    }
  }

  void _stopAll() {
    for (final sub in _rtdbSubs.values) {
      sub.cancel();
    }
    _rtdbSubs.clear();
    _baselineDone.clear();
    _seenEvents.clear();
    for (final sub in _tournamentSubs.values) {
      sub.cancel();
    }
    _tournamentSubs.clear();
    _matchToTournament.clear();
    _tournamentMatchIds = <String>{};
  }

  void dispose() => _stopAll();
}

/// Kept alive for the whole app lifetime by being watched from the app shell.
final matchAlertListenerProvider = Provider<MatchAlertListener>((ref) {
  final listener = MatchAlertListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
