import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';
import 'package:sportyapp/data/repositories/live_stream_repository.dart';
import 'package:sportyapp/data/services/agora_rtc_service.dart';
import 'package:sportyapp/data/services/agora_token_service.dart';

// ── Firestore ─────────────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ── Token service ─────────────────────────────────────────────────────────

final agoraTokenServiceProvider = Provider<AgoraTokenService>((ref) {
  return AgoraTokenService(FirebaseFunctions.instance);
});

// ── Agora RTC service (singleton — one engine for the whole app) ─────────

final agoraRtcServiceProvider = Provider<AgoraRtcService>((ref) {
  final tokenService = ref.read(agoraTokenServiceProvider);
  final service = AgoraRtcService(tokenService);
  ref.onDispose(() => service.dispose());
  return service;
});

// ── Repository ────────────────────────────────────────────────────────────

final liveStreamRepositoryProvider = Provider<LiveStreamRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestoreLiveStreamRepository(firestore);
});

// ── Stream of active live streams (auto‑updating) ────────────────────────

final activeLiveStreamsProvider =
    StreamProvider<List<LiveStreamModel>>((ref) {
  final repo = ref.watch(liveStreamRepositoryProvider);
  return repo.watchActiveStreams();
});
