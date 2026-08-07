import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';
import 'package:sportyapp/data/repositories/live_stream_repository.dart';

// ── Firestore ─────────────────────────────────────────────────────────────

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
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
