// lib/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart
// Riverpod StateNotifier that loads/saves per-match notification prefs.
//
// The source of truth is Firestore at `users/{userId}/matchAlerts/{matchId}`,
// which the client-side alert listener (see core/services/match_alert_service.dart)
// uses to know which matches to watch. The snapshot listener also keeps the
// toggle UI in sync when the user changes it on another device.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/match_notification_prefs.dart';
import 'package:sportyapp/data/models/tournament_notification_prefs.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class MatchNotificationPrefsNotifier
    extends StateNotifier<MatchNotificationPrefs> {
  final Ref _ref;
  final String _matchId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  MatchNotificationPrefsNotifier(this._ref, this._matchId)
      : super(MatchNotificationPrefs(matchId: _matchId)) {
    _listen();
    // Re-subscribe when the user signs in/out so alerts track the right user.
    _ref.listen(currentUserProvider, (_, __) => _listen());
  }

  String? get _userId => _ref.read(currentUserProvider)?.id;

  DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = _userId;
    if (uid == null) return null;
    return _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(uid)
        .collection('matchAlerts')
        .doc(_matchId);
  }

  void _listen() {
    _sub?.cancel();
    _sub = null;
    final ref = _docRef();
    if (ref == null) return;
    _sub = ref.snapshots().listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        state = MatchNotificationPrefs.fromJson({
          'matchId': _matchId,
          ...doc.data()!,
        });
      } else {
        state = MatchNotificationPrefs(matchId: _matchId);
      }
    });
  }

  Future<void> _write(MatchNotificationPrefs prefs) async {
    final ref = _docRef();
    if (ref == null) return;
    await ref.set({
      ...prefs.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Toggle helpers ────────────────────────────────────────────────────────

  Future<void> toggleAlerts() async {
    MatchNotificationPrefs next;
    if (!state.enabled) {
      // Turning the bell ON: default all event types to ON so the user
      // gets a useful subscription right away. Individual toggles refine it.
      next = state.copyWith(
        enabled: true,
        matchStart: true,
        firstInningsStart: true,
        secondInningsStart: true,
        wicket: true,
        matchComplete: true,
      );
    } else {
      next = state.copyWith(enabled: false);
    }
    state = next;
    await _write(next);
  }

  Future<void> toggleMatchStart() async {
    final next = state.copyWith(
      enabled: true,
      matchStart: !state.matchStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleFirstInningsStart() async {
    final next = state.copyWith(
      enabled: true,
      firstInningsStart: !state.firstInningsStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleSecondInningsStart() async {
    final next = state.copyWith(
      enabled: true,
      secondInningsStart: !state.secondInningsStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleWicket() async {
    final next = state.copyWith(
      enabled: true,
      wicket: !state.wicket,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleMatchComplete() async {
    final next = state.copyWith(
      enabled: true,
      matchComplete: !state.matchComplete,
    );
    state = next;
    await _write(next);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final matchNotificationPrefsProvider = StateNotifierProvider.family<
    MatchNotificationPrefsNotifier,
    MatchNotificationPrefs,
    String>((ref, matchId) => MatchNotificationPrefsNotifier(ref, matchId));

/// Streams every match-alert subscription for the current user as a
/// matchId → prefs map. This is what the RTDB alert listener uses to know which
/// matches to watch and which events the user wants notified. Emits an empty
/// map while signed out.
final matchAlertsMapProvider =
    StreamProvider<Map<String, MatchNotificationPrefs>>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return Stream.value(const <String, MatchNotificationPrefs>{});
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('matchAlerts')
      .snapshots()
      .map((snap) {
    final map = <String, MatchNotificationPrefs>{};
    for (final doc in snap.docs) {
      map[doc.id] = MatchNotificationPrefs.fromJson({
        'matchId': doc.id,
        ...doc.data(),
      });
    }
    return map;
  });
});

// ── Tournament alerts ─────────────────────────────────────────────────────────

/// StateNotifier that loads/saves per-tournament notification prefs, persisted
/// to Firestore at `users/{userId}/tournamentAlerts/{tournamentId}`.
class TournamentNotificationPrefsNotifier
    extends StateNotifier<TournamentNotificationPrefs> {
  final Ref _ref;
  final String _tournamentId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  TournamentNotificationPrefsNotifier(this._ref, this._tournamentId)
      : super(TournamentNotificationPrefs(tournamentId: _tournamentId)) {
    _listen();
    _ref.listen(currentUserProvider, (_, __) => _listen());
  }

  String? get _userId => _ref.read(currentUserProvider)?.id;

  DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = _userId;
    if (uid == null) return null;
    return _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(uid)
        .collection('tournamentAlerts')
        .doc(_tournamentId);
  }

  void _listen() {
    _sub?.cancel();
    _sub = null;
    final ref = _docRef();
    if (ref == null) return;
    _sub = ref.snapshots().listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        state = TournamentNotificationPrefs.fromJson({
          'tournamentId': _tournamentId,
          ...doc.data()!,
        });
      } else {
        state = TournamentNotificationPrefs(tournamentId: _tournamentId);
      }
    });
  }

  Future<void> _write(TournamentNotificationPrefs prefs) async {
    final ref = _docRef();
    if (ref == null) return;
    await ref.set({
      ...prefs.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleAlerts() async {
    TournamentNotificationPrefs next;
    if (!state.enabled) {
      next = state.copyWith(
        enabled: true,
        matchStart: true,
        firstInningsStart: true,
        secondInningsStart: true,
        wicket: true,
        matchComplete: true,
      );
    } else {
      next = state.copyWith(enabled: false);
    }
    state = next;
    await _write(next);
  }

  Future<void> toggleMatchStart() async {
    final next = state.copyWith(
      enabled: true,
      matchStart: !state.matchStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleFirstInningsStart() async {
    final next = state.copyWith(
      enabled: true,
      firstInningsStart: !state.firstInningsStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleSecondInningsStart() async {
    final next = state.copyWith(
      enabled: true,
      secondInningsStart: !state.secondInningsStart,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleWicket() async {
    final next = state.copyWith(
      enabled: true,
      wicket: !state.wicket,
    );
    state = next;
    await _write(next);
  }

  Future<void> toggleMatchComplete() async {
    final next = state.copyWith(
      enabled: true,
      matchComplete: !state.matchComplete,
    );
    state = next;
    await _write(next);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final tournamentNotificationPrefsProvider = StateNotifierProvider.family<
    TournamentNotificationPrefsNotifier,
    TournamentNotificationPrefs,
    String>(
    (ref, tournamentId) =>
        TournamentNotificationPrefsNotifier(ref, tournamentId));

/// Streams every tournament-alert subscription for the current user as a
/// tournamentId → prefs map, which the RTDB alert listener uses to resolve the
/// tournaments' matches and notify on them. Emits an empty map while signed out.
final tournamentAlertsMapProvider =
    StreamProvider<Map<String, TournamentNotificationPrefs>>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) {
    return Stream.value(const <String, TournamentNotificationPrefs>{});
  }
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('tournamentAlerts')
      .snapshots()
      .map((snap) {
    final map = <String, TournamentNotificationPrefs>{};
    for (final doc in snap.docs) {
      map[doc.id] = TournamentNotificationPrefs.fromJson({
        'tournamentId': doc.id,
        ...doc.data(),
      });
    }
    return map;
  });
});
