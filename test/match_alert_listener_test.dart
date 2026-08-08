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
import 'package:sportyapp/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart';

const _uid = 'spectator-1';
const _matchId = 'match-1';

MatchNotificationPrefs _prefs({
  bool enabled = true,
  bool start = true,
  bool wicket = true,
  bool complete = true,
}) =>
    MatchNotificationPrefs(
      matchId: _matchId,
      enabled: enabled,
      matchStart: start,
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
  late StreamController<Map<String, MatchNotificationPrefs>> prefsStream;
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
    prefsStream =
        StreamController<Map<String, MatchNotificationPrefs>>.broadcast();
    container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(uidProvider)),
      matchAlertsMapProvider.overrideWith((ref) => prefsStream.stream),
      matchAlertListenerProvider.overrideWith(
        (ref) => MatchAlertListener(
          ref,
          notify: notify,
          watchLiveMatch: (matchId) => rtdb.stream,
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
        'title': 'CRIXORA',
        'body': 'Alpha vs Beta has started',
      },
      {
        'matchId': _matchId,
        'type': 'wicket',
        'title': 'CRIXORA',
        'body': 'Alpha vs Beta — Wicket!',
      },
      {
        'matchId': _matchId,
        'type': 'complete',
        'title': 'CRIXORA',
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
}
