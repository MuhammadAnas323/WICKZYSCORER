import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/data/models/iptv_settings.dart';
import 'package:sportyapp/data/repositories/iptv_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/data/services/iptv_service.dart';

final iptvRepositoryProvider = Provider<IptvRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return IptvRepository(firestore);
});

final iptvServiceProvider = Provider<IptvService>((ref) {
  final repository = ref.watch(iptvRepositoryProvider);
  return IptvService(repository);
});

final iptvChannelsStreamProvider = StreamProvider<List<IptvChannel>>((ref) {
  final repository = ref.watch(iptvRepositoryProvider);
  return repository.watchChannels();
});

class IptvState {
  final bool isDownloading;
  final String downloadPhase;
  final int? totalChannels;
  final int? playableChannels;
  final IptvSettings? settings;
  final String? error;
  final String searchQuery;
  final String? selectedGroup;

  const IptvState({
    this.isDownloading = false,
    this.downloadPhase = '',
    this.totalChannels,
    this.playableChannels,
    this.settings,
    this.error,
    this.searchQuery = '',
    this.selectedGroup,
  });

  List<IptvChannel> filterChannels(List<IptvChannel> channels) {
    var result = channels;
    if (selectedGroup != null && selectedGroup!.isNotEmpty) {
      result = result.where((c) => c.group == selectedGroup).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((c) =>
        c.channelName.toLowerCase().contains(q) ||
        (c.country?.toLowerCase().contains(q) ?? false) ||
        (c.group?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    return result;
  }

  IptvState copyWith({
    bool? isDownloading,
    String? downloadPhase,
    int? totalChannels,
    int? playableChannels,
    IptvSettings? settings,
    String? error,
    String? searchQuery,
    String? selectedGroup,
    bool clearError = false,
  }) => IptvState(
    isDownloading: isDownloading ?? this.isDownloading,
    downloadPhase: downloadPhase ?? this.downloadPhase,
    totalChannels: totalChannels ?? this.totalChannels,
    playableChannels: playableChannels ?? this.playableChannels,
    settings: settings ?? this.settings,
    error: clearError ? null : (error ?? this.error),
    searchQuery: searchQuery ?? this.searchQuery,
    selectedGroup: selectedGroup ?? this.selectedGroup,
  );
}

final iptvProvider = StateNotifierProvider<IptvNotifier, IptvState>((ref) {
  final service = ref.watch(iptvServiceProvider);
  return IptvNotifier(service);
});

class IptvNotifier extends StateNotifier<IptvState> {
  final IptvService _service;

  IptvNotifier(this._service) : super(const IptvState()) {
    _init();
  }

  Future<void> _init() async {
    final settings = await _service.loadSettings();
    state = state.copyWith(settings: settings);
  }

  Future<void> downloadPlaylist(String url) async {
    state = state.copyWith(
      isDownloading: true,
      downloadPhase: 'Downloading Playlist...',
      clearError: true,
    );

    try {
      state = state.copyWith(downloadPhase: 'Parsing Channels...');
      final result = await _service.downloadAndSave(url);

      state = state.copyWith(
        isDownloading: false,
        downloadPhase: 'Playlist Imported Successfully',
        totalChannels: result.totalChannels,
        playableChannels: result.playableChannels,
        settings: IptvSettings(
          playlistUrl: url,
          lastUpdated: DateTime.now(),
          channelCount: result.totalChannels,
        ),
      );
    } on TimeoutException {
      state = state.copyWith(
        isDownloading: false,
        downloadPhase: '',
        error: 'Request timed out. The playlist server may be slow or unreachable.',
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        downloadPhase: '',
        error: e is IptvException ? e.message : 'Failed to download playlist: $e',
      );
    }
  }

  Future<void> refreshPlaylist(String url) async {
    await downloadPlaylist(url);
  }

  Future<void> deleteChannel(String channelId) async {
    await _service.deleteChannel(channelId);
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state = const IptvState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedGroup(String? group) {
    state = state.copyWith(selectedGroup: group);
  }
}
