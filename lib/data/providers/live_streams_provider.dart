import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/repositories/streaming_repository.dart';

final streamingRepositoryProvider = Provider<StreamingRepository>((ref) {
  final repo = FirestoreStreamingRepository(
    FirebaseFirestore.instance,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final liveStreamsProvider = StreamProvider<List<StreamModel>>((ref) {
  final repo = ref.watch(streamingRepositoryProvider);
  if (repo is FirestoreStreamingRepository) {
    return repo.watchActiveStreams();
  }
  return Stream.periodic(
    const Duration(seconds: 10),
    (_) => repo.getActiveStreams(),
  ).asyncMap((_) async => await repo.getActiveStreams());
});
