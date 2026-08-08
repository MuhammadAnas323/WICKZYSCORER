// lib/core/services/notification_service.dart
// Device-level local notifications powered by flutter_local_notifications.
//
// Three distinct Android channels drive the three match alert events, each with
// its own custom sound from `android/app/src/main/res/raw`:
//   - match_start_channel    → match_start.mp3
//   - wicket_channel         → wicket.mp3
//   - match_complete_channel → match_complete.mp3
//
// Match alerts are delivered by the RTDB listener (see match_alert_service.dart)
// while the spectator app is active — no Cloud Functions or FCM required.
// Tapping a notification routes to the match screen via the [onMatchTap]
// callback.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Invoked when the user taps a match-alert notification. Set by the app
  /// shell once the router is available; taps that arrive before that are
  /// buffered and delivered when the callback is set.
  ValueChanged<String>? _onMatchTap;
  String? _pendingMatchId;

  set onMatchTap(ValueChanged<String>? callback) {
    _onMatchTap = callback;
    final pending = _pendingMatchId;
    if (pending != null && callback != null) {
      _pendingMatchId = null;
      callback(pending);
    }
  }

  // ── Channel IDs (must match the Android notification channels) ───────────
  static const _chMatchStart = 'match_start_channel';
  static const _chWicket = 'wicket_channel';
  static const _chMatchComplete = 'match_complete_channel';

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _createAndroidChannels();

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    final matchId = response.payload;
    if (matchId == null || matchId.isEmpty) return;
    final callback = _onMatchTap;
    if (callback != null) {
      callback(matchId);
    } else {
      _pendingMatchId = matchId;
    }
  }

  /// Creates the three event-specific Android notification channels (each with
  /// its own raw-resource sound). Creating them explicitly guarantees the sound
  /// configuration is applied on first install.
  Future<void> _createAndroidChannels() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _chMatchStart,
        'Match Start Alerts',
        description: 'Alerts when a match you follow starts',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('match_start'),
      ),
    );
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _chWicket,
        'Wicket Alerts',
        description: 'Alerts when a wicket falls in a match you follow',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('wicket'),
      ),
    );
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        _chMatchComplete,
        'Match Complete Alerts',
        description: 'Alerts when a match you follow is completed',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('match_complete'),
      ),
    );
  }

  // ── Android notification details helpers ──────────────────────────────────
  AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required String soundResource,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundResource),
    );
  }

  NotificationDetails _details(AndroidNotificationDetails android) {
    return NotificationDetails(
      android: android,
      iOS: const DarwinNotificationDetails(presentSound: true),
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Match started alert ("Team A vs Team B has started").
  Future<void> showMatchStarted({
    required String matchId,
    required String title,
    required String body,
  }) async {
    await _ensureInit();
    await _plugin.show(
      _idFor(matchId, 0),
      title,
      body,
      _details(_androidDetails(
        channelId: _chMatchStart,
        channelName: 'Match Start Alerts',
        channelDesc: 'Alerts when a match you follow starts',
        soundResource: 'match_start',
      )),
      payload: matchId,
    );
  }

  /// Wicket alert ("Team A vs Team B — Wicket! ...").
  Future<void> showWicket({
    required String matchId,
    required String title,
    required String body,
  }) async {
    await _ensureInit();
    await _plugin.show(
      _idFor(matchId, 1),
      title,
      body,
      _details(_androidDetails(
        channelId: _chWicket,
        channelName: 'Wicket Alerts',
        channelDesc: 'Alerts when a wicket falls in a match you follow',
        soundResource: 'wicket',
      )),
      payload: matchId,
    );
  }

  /// Match completed alert ("Team A vs Team B — Match completed").
  Future<void> showMatchCompleted({
    required String matchId,
    required String title,
    required String body,
  }) async {
    await _ensureInit();
    await _plugin.show(
      _idFor(matchId, 2),
      title,
      body,
      _details(_androidDetails(
        channelId: _chMatchComplete,
        channelName: 'Match Complete Alerts',
        channelDesc: 'Alerts when a match you follow is completed',
        soundResource: 'match_complete',
      )),
      payload: matchId,
    );
  }

  /// Cancel all notifications shown for a given match (all three events).
  Future<void> cancelMatchNotifications(String matchId) async {
    await _ensureInit();
    for (var i = 0; i < 3; i++) {
      await _plugin.cancel(_idFor(matchId, i));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (!_initialized) await init();
  }

  /// Deterministic int ID from matchId + event slot (0=start, 1=wicket,
  /// 2=complete) so re-shown notifications replace older ones instead of
  /// stacking duplicates.
  int _idFor(String matchId, int slot) {
    final hash = matchId.hashCode.abs() % 9999990;
    return hash + slot;
  }
}
