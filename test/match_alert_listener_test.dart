// test/match_alert_listener_test.dart
// Unit tests for the client-side match alert listener
// (lib/core/services/match_alert_service.dart).
//
// These simulate the two-device flow entirely in-process:
//   • the SCORER side is a controlled RTDB stream (`liveMatches/{matchId}`)
//     that emits the `lastEvent` payloads a real scorer publishes
//     (start → balls → wicket → complete → node deleted);
//   • the SPECTATOR side is a MatchAlertListener built against that stream
//     with a fake notify callback that records every notification.
//
// They verify the exact acceptance criteria for the physical-device test:
//   • exactly one notification per start/wicket/complete event, with no
//     notification for ordinary balls;
//   • the correct title/body per event type;
//   • re-published events (same event id) are never notified twice;
//   • subscribing mid-match never replays events that already happened;
//   • enabling alerts before the match starts still fires the start alert;
//   • disabling alerts immediately unsubscribes and stops notifications;
//   • event-type prefs gate which notifications are shown;
//   • signing out tears down every subscription.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/services/match_alert_service.dart';
import 'package:sportyapp/data/models/match_notification_prefs.dart';
import 'package:sportyapp/data/models/tournament_notification_prefs.dart';
import 'package:sportyapp/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart';

const _uid = 'spectator-1';
const _matchId = 'match-1';

MatchNotificationPrefs _prefs({
  bool enabled = true,
  bool start = true,
  bool firstInnings = true,
  bool secondInnings = true,
  bool wicket = true,
  bool complete = true,
}) =>
    MatchNotificationPrefs(
      matchId: _matchId,
      enabled: enabled,
      matchStart: start,
      firstInningsStart: firstInnings,
      secondInningsStart: secondInnings,
      wicket: wicket,
      matchComplete: complete,
    );

/// A live-payload the way the scorer publishes it to RTDB.
Map<String, dynamic> _payload(String type, {String? id}) => {
      'team1Name': 'Alpha',
      'team2Name': 'Beta',
      'lastEvent': {
        'id': id ?? '${_matchId}_$type',
        'type': type,
        'matchId': _matchId,
      },
    };

void main() {
  late ProviderContainer container;
  late StreamController<Map<String, dynamic>?> rtdb;
  late Map<String, StreamController<Map<String, dynamic>?>> matchStreams;
  late StreamController<Map<String, MatchNotificationPrefs>> prefsStream;
  late StreamController<Map<String, TournamentNotificationPrefs>>
      tournamentPrefsStream;
  late StreamController<List<Map<String, dynamic>>> tournamentMatchesCtrl;
  late StateProvider<String?> uidProvider;
  final notifications = <Map<String, String>>[];

  Future<void> notify({
    required String matchId,
    required String eventType,
    required String title,
    required String body,
  }) {
    notifications.add({
      'matchId': matchId,
      'type': eventType,
      'title': title,
      'body': body,
    });
    return Future.value();
  }

  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  void build() {
    uidProvider = StateProvider<String?>((ref) => _uid);
    rtdb = StreamController<Map<String, dynamic>?>.broadcast();
    matchStreams = <String, StreamController<Map<String, dynamic>?>>{};
    prefsStream =
        StreamController<Map<String, MatchNotificationPrefs>>.broadcast();
    tournamentPrefsStream =
        StreamController<Map<String, TournamentNotificationPrefs>>.broadcast();
    tournamentMatchesCtrl =
        StreamController<List<Map<String, dynamic>>>.broadcast();
    container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(uidProvider)),
      matchAlertsMapProvider.overrideWith((ref) => prefsStream.stream),
      tournamentAlertsMapProvider.overrideWith(
        (ref) => tournamentPrefsStream.stream,
      ),
      matchAlertListenerProvider.overrideWith(
        (ref) => MatchAlertListener(
          ref,
          notify: notify,
          watchLiveMatch: (matchId) =>
              (matchStreams[matchId] ?? rtdb).stream,
          watchTournamentMatches: (tournamentId) =>
              tournamentMatchesCtrl.stream,
        ),
      ),
    ]);
  }

  MatchAlertListener listener() => container.read(matchAlertListenerProvider);

  void emitPrefs(MatchNotificationPrefs prefs) {
    prefsStream.add({_matchId: prefs});
  }

  setUp(() {
    notifications.clear();
    build();
    // Instantiate the listener up front so it subscribes to both providers
    // before any test event is emitted (broadcast streams don't replay).
    listener();
  });

  tearDown(() {
    listener().dispose();
    container.dispose();
  });

  test('full flow: start, balls, wicket, complete → exactly one notification '
      'each, correct titles, no ball notifications', () async {
    emitPrefs(_prefs());
    await flush();
    expect(listener().isWatching(_matchId), isTrue);

    // Subscribed before the match started: RTDB node is empty.
    rtdb.add(null);
    await flush();

    // Scorer starts the match.
    rtdb.add(_payload('start'));
    await flush();

    // Ordinary balls — must never notify.
    rtdb.add(_payload('ball', id: '${_matchId}_inn1_o1_b1'));
    rtdb.add(_payload('ball', id: '${_matchId}_inn1_o1_b2'));
    await flush();

    // A wicket falls.
    rtdb.add(_payload('wicket', id: '${_matchId}_inn1_o2_b1'));
    await flush();

    // Match completed, then the live node is deleted.
    rtdb.add(_payload('complete'));
    rtdb.add(null);
    await flush();

    expect(notifications, [
      {
        'matchId': _matchId,
        'type': 'start',
        'title': 'WickzyScorer',
        'body': 'Alpha vs Beta has started',
      },
      {
        'matchId': _matchId,
        'type': 'wicket',
        'title': 'WickzyScorer',
        'body': 'Alpha vs Beta — Wicket!',
      },
      {
        'matchId': _matchId,
        'type': 'complete',
        'title': 'WickzyScorer',
        'body': 'Alpha vs Beta — Match completed',
      },
    ]);
  });

  test('re-published events (same id) are never notified twice', () async {
    emitPrefs(_prefs());
    await flush();
    // Subscribed before the match started: the node is empty.
    rtdb.add(null);
    await flush();

    // Match starts but RTDB re-emits the same start payload several times.
    rtdb.add(_payload('start'));
    rtdb.add(_payload('start'));
    rtdb.add(_payload('start'));
    await flush();

    expect(notifications.where((n) => n['type'] == 'start'), hasLength(1));
  });

  test('subscribing mid-match never replays events that already happened',
      () async {
    emitPrefs(_prefs());
    await flush();

    // First emission is the current live state (baseline) → not notified.
    rtdb.add(_payload('ball', id: '${_matchId}_inn1_o3_b4'));
    await flush();
    expect(notifications, isEmpty);

    // A NEW wicket after subscribing → notified exactly once, even if the
    // scorer re-emits it.
    rtdb.add(_payload('wicket', id: '${_matchId}_inn1_o3_b5'));
    rtdb.add(_payload('wicket', id: '${_matchId}_inn1_o3_b5'));
    await flush();
    expect(notifications.where((n) => n['type'] == 'wicket'), hasLength(1));
  });

  test('disabling alerts immediately unsubscribes and stops notifications',
      () async {
    emitPrefs(_prefs());
    await flush();
    expect(listener().isWatching(_matchId), isTrue);

    rtdb.add(null);
    await flush();

    rtdb.add(_payload('start'));
    await flush();
    expect(notifications.where((n) => n['type'] == 'start'), hasLength(1));

    // User toggles the bell OFF on the match detail screen.
    emitPrefs(_prefs(enabled: false));
    await flush();
    expect(listener().isWatching(_matchId), isFalse);

    // New events after disabling must never reach the spectator.
    rtdb.add(_payload('wicket'));
    rtdb.add(_payload('complete'));
    await flush();
    expect(notifications, hasLength(1));
  });

  test('event-type prefs gate which notifications are shown', () async {
    emitPrefs(_prefs(start: true, wicket: false, complete: true));
    await flush();
    rtdb.add(null);
    await flush();

    rtdb.add(_payload('start'));
    rtdb.add(_payload('wicket'));
    rtdb.add(_payload('complete'));
    await flush();

    final types = notifications.map((n) => n['type']).toList();
    expect(types, ['start', 'complete']);
  });

  test('signing out tears down every subscription', () async {
    emitPrefs(_prefs());
    await flush();
    expect(listener().isWatching(_matchId), isTrue);

    container.read(uidProvider.notifier).state = null;
    await flush();

    expect(listener().isWatching(_matchId), isFalse);
    rtdb.add(_payload('start'));
    await flush();
    expect(notifications, isEmpty);
  });

  test('innings-start events notify only when the matching prefs are on',
      () async {
    emitPrefs(_prefs(start: false, wicket: false, complete: false));
    await flush();
    rtdb.add(null);
    await flush();

    rtdb.add(_payload('first_innings_start'));
    rtdb.add(_payload('second_innings_start'));
    await flush();

    final types = notifications.map((n) => n['type']).toList();
    expect(types, ['first_innings_start', 'second_innings_start']);
    expect(notifications.first['body'],
        'Alpha vs Beta — 1st innings has started');
    expect(notifications.last['body'],
        'Alpha vs Beta — 2nd innings has started');
  });

  test('innings-start events are gated off by their prefs', () async {
    emitPrefs(_prefs(firstInnings: false, secondInnings: false));
    await flush();
    rtdb.add(null);
    await flush();

    rtdb.add(_payload('first_innings_start'));
    rtdb.add(_payload('second_innings_start'));
    await flush();

    expect(notifications, isEmpty);
  });

  test('tournament alerts notify for every match of the tournament',
      () async {
    tournamentPrefsStream.add({
      'tournament-1': TournamentNotificationPrefs(
        tournamentId: 'tournament-1',
        enabled: true,
        matchStart: true,
        firstInningsStart: true,
        secondInningsStart: true,
        wicket: true,
        matchComplete: true,
      ),
    });
    await flush();

    // Per-match RTDB streams (real RTDB nodes are per-match). Register them
    // before the matches arrive so the listener subscribes to the right node.
    matchStreams['match-2'] =
        StreamController<Map<String, dynamic>?>.broadcast();
    matchStreams['match-3'] =
        StreamController<Map<String, dynamic>?>.broadcast();

    // The tournament's Firestore matches are resolved; one is not yet live,
    // the other is already in progress.
    tournamentMatchesCtrl.add([
      {'id': 'match-2', 'status': 'scheduled', 'tournamentId': 'tournament-1'},
      {'id': 'match-3', 'status': 'inProgress', 'tournamentId': 'tournament-1'},
    ]);
    await flush();
    expect(listener().isWatching('match-2'), isTrue);
    expect(listener().isWatching('match-3'), isTrue);

    // Baseline for the not-yet-live match.
    matchStreams['match-2']!.add(null);
    await flush();

    // match-2 starts → the tournament's matchStart pref applies.
    matchStreams['match-2']!.add({
      'team1Name': 'Alpha',
      'team2Name': 'Beta',
      'lastEvent': {
        'id': 'match-2_start',
        'type': 'start',
      },
    });
    await flush();

    // match-3 is already live: its first emission is the baseline (a wicket
    // already fallen) so it is remembered, not notified.
    matchStreams['match-3']!.add({
      'team1Name': 'Alpha',
      'team2Name': 'Beta',
      'lastEvent': {
        'id': 'match-3_old_wicket',
        'type': 'wicket',
      },
    });
    await flush();

    final matched = notifications.where((n) => n['matchId'] == 'match-2');
    expect(matched, hasLength(1));
    expect(matched.single['type'], 'start');
    expect(matched.single['body'], 'Alpha vs Beta has started');
    expect(notifications, hasLength(1));
  });

  test('completed tournament matches are not watched', () async {
    tournamentPrefsStream.add({
      'tournament-1': TournamentNotificationPrefs(
        tournamentId: 'tournament-1',
        enabled: true,
        matchStart: true,
        firstInningsStart: true,
        secondInningsStart: true,
        wicket: true,
        matchComplete: true,
      ),
    });
    await flush();

    tournamentMatchesCtrl.add([
      {'id': 'match-done', 'status': 'completed', 'tournamentId': 'tournament-1'},
      {'id': 'match-live', 'status': 'inProgress', 'tournamentId': 'tournament-1'},
    ]);
    await flush();

    expect(listener().isWatching('match-done'), isFalse);
    expect(listener().isWatching('match-live'), isTrue);
  });
}
