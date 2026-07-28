import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/m3u_channel_model.dart';
import 'package:sportyapp/data/services/m3u_service.dart';

final m3uServiceProvider = Provider<M3uService>((ref) => M3uService());

class M3uState {
  final bool isLoading;
  final M3uPlaylist? playlist;
  final String? error;
  final String searchQuery;
  final String? selectedGroup;

  const M3uState({
    this.isLoading = false,
    this.playlist,
    this.error,
    this.searchQuery = '',
    this.selectedGroup,
  });

  List<M3uChannel> get filteredChannels {
    if (playlist == null) return [];
    var channels = playlist!.channels;

    if (selectedGroup != null && selectedGroup!.isNotEmpty) {
      channels = channels.where((c) => c.group == selectedGroup).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      channels = channels.where((c) =>
        c.name.toLowerCase().contains(query) ||
        (c.group?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return channels;
  }

  bool get hasPlaylist => playlist != null;

  M3uState copyWith({
    bool? isLoading,
    M3uPlaylist? playlist,
    String? error,
    String? searchQuery,
    String? selectedGroup,
    bool clearPlaylist = false,
    bool clearError = false,
  }) => M3uState(
    isLoading: isLoading ?? this.isLoading,
    playlist: clearPlaylist ? null : (playlist ?? this.playlist),
    error: clearError ? null : (error ?? this.error),
    searchQuery: searchQuery ?? this.searchQuery,
    selectedGroup: selectedGroup ?? this.selectedGroup,
  );
}

final m3uProvider = StateNotifierProvider<M3uNotifier, M3uState>((ref) {
  final service = ref.watch(m3uServiceProvider);
  return M3uNotifier(service);
});

class M3uNotifier extends StateNotifier<M3uState> {
  final M3uService _service;

  M3uNotifier(this._service) : super(const M3uState()) {
    _loadCached();
  }

  Future<void> _loadCached() async {
    final cached = await _service.loadCachedPlaylist();
    if (cached != null) {
      state = state.copyWith(playlist: cached);
    }
  }

  Future<void> loadPlaylist(String url) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final playlist = await _service.fetchAndParse(url);
      await _service.cachePlaylist(playlist);
      state = state.copyWith(isLoading: false, playlist: playlist);
    } on TimeoutException {
      state = state.copyWith(
        isLoading: false,
        error: 'Request timed out. The playlist server may be slow or unreachable.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is HttpException ? e.message : 'Failed to load playlist: $e',
      );
    }
  }

  Future<void> refresh() async {
    final url = state.playlist?.sourceUrl;
    if (url == null || url.isEmpty) return;
    await loadPlaylist(url);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedGroup(String? group) {
    state = state.copyWith(selectedGroup: group);
  }

  void clear() {
    state = const M3uState();
    _service.clearCache();
  }
}
