import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/services/realtime_database_service.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';

final realtimeDatabaseServiceProvider = Provider<IRealtimeDatabaseService>((ref) {
  final service = RealtimeDatabaseService(FirebaseDatabase.instance);
  ref.onDispose(() => service.dispose());
  return service;
});

final liveMatchRepositoryProvider = Provider<LiveMatchRepository>((ref) {
  final rtdb = ref.watch(realtimeDatabaseServiceProvider);
  return RealtimeLiveMatchRepository(rtdb);
});

final liveMatchDataProvider = StreamProvider.family<LiveMatchData, String>(
  (ref, matchId) {
    final repo = ref.watch(liveMatchRepositoryProvider);
    return repo.watchLiveMatch(matchId);
  },
);

final liveMatchStatusProvider = StreamProvider.family<String, String>(
  (ref, matchId) {
    final rtdb = ref.watch(realtimeDatabaseServiceProvider);
    return rtdb.watchLiveMatchRaw(matchId).map((event) {
      if (event.snapshot.value == null) return 'unknown';
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return data['status'] as String? ?? 'unknown';
    });
  },
);

final activeLiveMatchIdsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(liveMatchRepositoryProvider);
  return repo.getAllLiveMatchIds();
});
