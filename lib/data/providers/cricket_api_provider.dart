import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/cricket_api_config.dart';
import 'package:sportyapp/data/models/cricket_feed_item.dart';
import 'package:sportyapp/data/services/cricket_api_service.dart';

final cricketApiServiceProvider = Provider<CricketApiService>((ref) {
  return CricketApiService();
});

class CricketApiState {
  final List<CricketApiConfig> apis;
  final List<CricketFeedItem> feedItems;
  final bool isLoading;
  final Map<String, bool> testingMap;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const CricketApiState({
    this.apis = const [],
    this.feedItems = const [],
    this.isLoading = false,
    this.testingMap = const {},
    this.errorMessage,
    this.lastUpdated,
  });

  CricketApiState copyWith({
    List<CricketApiConfig>? apis,
    List<CricketFeedItem>? feedItems,
    bool? isLoading,
    Map<String, bool>? testingMap,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return CricketApiState(
      apis: apis ?? this.apis,
      feedItems: feedItems ?? this.feedItems,
      isLoading: isLoading ?? this.isLoading,
      testingMap: testingMap ?? this.testingMap,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  int get connectedCount => apis.where((a) => a.isActive && a.status == CricketApiStatus.connected).length;
  int get activeCount => apis.where((a) => a.isActive).length;
  int get totalCount => apis.length;
}

final cricketApiProvider = StateNotifierProvider<CricketApiNotifier, CricketApiState>((ref) {
  final service = ref.watch(cricketApiServiceProvider);
  return CricketApiNotifier(service);
});

class CricketApiNotifier extends StateNotifier<CricketApiState> {
  final CricketApiService _service;
  StreamSubscription<List<CricketApiConfig>>? _apiWatchSub;

  CricketApiNotifier(this._service) : super(const CricketApiState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);

    // ── Load initial data (Firestore or local cache) ──────────────────────
    final loadedApis = await _service.loadApis();
    state = state.copyWith(apis: loadedApis);
    await refreshFeeds();

    // ── Subscribe to real-time Firestore updates ──────────────────────────
    // When any device saves a new or updated API list, all devices' UIs
    // will automatically see the change and re-fetch feeds.
    _apiWatchSub = _service.watchApis().listen((remoteApis) async {
      // Only react if the list actually changed
      final currentIds = state.apis.map((a) => a.id).toList()..sort();
      final remoteIds = remoteApis.map((a) => a.id).toList()..sort();
      final changed = currentIds.join(',') != remoteIds.join(',');
      if (changed && mounted) {
        state = state.copyWith(apis: remoteApis);
        await refreshFeeds();
      }
    }, onError: (_) {
      // Firestore watch unavailable (offline) — keep current state
    });
  }

  @override
  void dispose() {
    _apiWatchSub?.cancel();
    super.dispose();
  }

  Future<void> refreshFeeds() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final activeApis = state.apis.where((a) => a.isActive).toList();
    if (activeApis.isEmpty) {
      state = state.copyWith(
        feedItems: [],
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
      return;
    }

    try {
      // Concurrently fetch feeds from all active APIs
      final results = await Future.wait(
        activeApis.map((api) => _service.fetchFeedFromApi(api)),
      );

      final List<CricketFeedItem> aggregatedFeeds = [];
      final List<CricketApiConfig> updatedApis = List.from(state.apis);

      for (var i = 0; i < activeApis.length; i++) {
        final api = activeApis[i];
        final items = results[i];
        aggregatedFeeds.addAll(items);

        final index = updatedApis.indexWhere((a) => a.id == api.id);
        if (index != -1) {
          updatedApis[index] = updatedApis[index].copyWith(
            status: items.isNotEmpty ? CricketApiStatus.connected : CricketApiStatus.connected,
            lastTestedAt: DateTime.now(),
          );
        }
      }

      await _service.saveApis(updatedApis);

      state = state.copyWith(
        apis: updatedApis,
        feedItems: aggregatedFeeds,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch API feeds: ${e.toString()}',
      );
    }
  }

  Future<void> addApi(CricketApiConfig newApi) async {
    final updated = [...state.apis, newApi];
    state = state.copyWith(apis: updated);
    await _service.saveApis(updated);
    await testConnection(newApi.id);
    await refreshFeeds();
  }

  Future<void> updateApi(CricketApiConfig updatedApi) async {
    final updated = state.apis.map((a) => a.id == updatedApi.id ? updatedApi : a).toList();
    state = state.copyWith(apis: updated);
    await _service.saveApis(updated);
    await testConnection(updatedApi.id);
    await refreshFeeds();
  }

  Future<void> deleteApi(String id) async {
    final updated = state.apis.where((a) => a.id != id).toList();
    state = state.copyWith(apis: updated);
    await _service.saveApis(updated);
    await refreshFeeds();
  }

  Future<void> toggleApiActive(String id, bool isActive) async {
    final updated = state.apis.map((a) {
      if (a.id == id) {
        return a.copyWith(isActive: isActive);
      }
      return a;
    }).toList();

    state = state.copyWith(apis: updated);
    await _service.saveApis(updated);
    await refreshFeeds();
  }

  Future<void> testConnection(String id) async {
    final apiIndex = state.apis.indexWhere((a) => a.id == id);
    if (apiIndex == -1) return;

    final api = state.apis[apiIndex];

    // Set testing state
    final updatedTesting = Map<String, bool>.from(state.testingMap)..[id] = true;
    final apisTesting = List<CricketApiConfig>.from(state.apis);
    apisTesting[apiIndex] = api.copyWith(status: CricketApiStatus.testing);
    state = state.copyWith(apis: apisTesting, testingMap: updatedTesting);

    // Test API
    final testedApi = await _service.testApiConnection(api);

    final finalApis = List<CricketApiConfig>.from(state.apis);
    final finalIndex = finalApis.indexWhere((a) => a.id == id);
    if (finalIndex != -1) {
      finalApis[finalIndex] = testedApi;
    }

    final finalTesting = Map<String, bool>.from(state.testingMap)..remove(id);
    state = state.copyWith(apis: finalApis, testingMap: finalTesting);

    await _service.saveApis(finalApis);
  }

  Future<void> clearAllApis() async {
    state = state.copyWith(apis: [], feedItems: []);
    await _service.saveApis([]);
    await refreshFeeds();
  }
}
