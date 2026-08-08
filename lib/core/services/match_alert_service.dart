// lib/core/services/match_alert_service.dart
// Client-side match alert delivery.
//
// Match-start / wicket / match-complete alerts are delivered entirely from the
// spectator app — no Cloud Functions, FCM or paid Firebase services.
//
// The scorer publishes a compact live payload to the Realtime Database
// (`liveMatches/{matchId}`) on every ball, stamped with a `lastEvent` object:
//   { id: <stable event id>, type: start|ball|wicket|complete, ... }
//
// This listener watches the RTDB nodes of every match the signed-in user has
// enabled alerts for (read from Firestore `users/{uid}/matchAlerts`) and, while
// the app is active, shows a local notification with the event-specific custom
// sound when a new start/wicket/complete event arrives.
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

class MatchAlertListener {
  final Ref _ref;
  final MatchAlertNotify? _notify;
  final Stream<Map<String, dynamic>?> Function(String matchId)? _watchLiveMatch;

  /// matchIds whose first RTDB emission has already established the baseline.
  final Set<String> _baselineDone = {};
  final Set<String> _seenEvents = {};
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _rtdbSubs = {};
  Map<String, MatchNotificationPrefs> _prefs = {};
  String? _uid;

  MatchAlertListener(
    this._ref, {
    MatchAlertNotify? notify,
    Stream<Map<String, dynamic>?> Function(String matchId)? watchLiveMatch,
  })  : _notify = notify,
        _watchLiveMatch = watchLiveMatch {
    _ref.listen(currentUserIdProvider, (_, next) {
      _uid = next;
      _reconcile();
    }, fireImmediately: true);
    _ref.listen(matchAlertsMapProvider, (_, next) {
      _prefs = next.valueOrNull ?? const {};
      _reconcile();
    }, fireImmediately: true);
  }

  /// Whether the listener currently watches [matchId] (used by tests).
  bool isWatching(String matchId) => _rtdbSubs.containsKey(matchId);

  /// Reconciles the RTDB subscriptions with the current user + prefs.
  void _reconcile() {
    if (_uid == null) {
      _stopAll();
      return;
    }
    final desired = <String>{};
    _prefs.forEach((matchId, p) {
      if (p.enabled && (p.matchStart || p.wicket || p.matchComplete)) {
        desired.add(matchId);
      }
    });

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

    final prefs = _prefs[matchId];
    if (prefs == null || !prefs.enabled) return;

    final type = lastEvent['type'];
    final wants = switch (type) {
      'start' => prefs.matchStart,
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
  }

  void dispose() => _stopAll();
}

/// Kept alive for the whole app lifetime by being watched from the app shell.
final matchAlertListenerProvider = Provider<MatchAlertListener>((ref) {
  final listener = MatchAlertListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
});
