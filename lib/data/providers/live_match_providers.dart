import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'repository_providers.dart';

final liveMatchRepositoryProvider = Provider<LiveMatchRepository>((ref) {
  final rtdb = ref.watch(realtimeDatabaseProvider);
  final repo = RealtimeLiveMatchRepository(rtdb);
  ref.onDispose(() => repo.dispose());
  return repo;
});

final liveMatchDataProvider = StreamProvider.family<LiveMatchData, String>(
  (ref, matchId) {
    final repo = ref.watch(liveMatchRepositoryProvider);
    return repo.watchLiveMatch(matchId);
  },
);

final activeLiveMatchIdsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.watch(liveMatchRepositoryProvider);
  return repo.getAllLiveMatchIds();
});

final allLiveMatchesProvider = StreamProvider<Map<String, LiveMatchData>>((ref) {
  final rtdb = ref.watch(realtimeDatabaseProvider);
  return rtdb.watchAllLiveMatches().map((raw) {
    return raw.map((matchId, data) => MapEntry(matchId, LiveMatchData.fromJson(data)));
  });
});
