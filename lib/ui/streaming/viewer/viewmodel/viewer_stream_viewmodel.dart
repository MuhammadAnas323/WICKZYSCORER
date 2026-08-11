import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';
import 'package:sportyapp/data/repositories/live_stream_repository.dart';
import 'package:sportyapp/data/providers/live_providers.dart';

class ViewerStreamState {
  final bool isLoading;
  final bool hasJoined;
  final bool isHostOffline;
  final LiveStreamModel? streamDoc;
  final String? error;

  const ViewerStreamState({
    this.isLoading = true,
    this.hasJoined = false,
    this.isHostOffline = false,
    this.streamDoc,
    this.error,
  });

  ViewerStreamState copyWith({
    bool? isLoading,
    bool? hasJoined,
    bool? isHostOffline,
    LiveStreamModel? streamDoc,
    String? error,
  }) =>
      ViewerStreamState(
        isLoading: isLoading ?? this.isLoading,
        hasJoined: hasJoined ?? this.hasJoined,
        isHostOffline: isHostOffline ?? this.isHostOffline,
        streamDoc: streamDoc ?? this.streamDoc,
        error: error,
      );
}

class ViewerStreamViewModel extends StateNotifier<ViewerStreamState> {
  final LiveStreamRepository _repository;
  final String streamId;

  StreamSubscription<LiveStreamModel?>? _streamDocSub;

  ViewerStreamViewModel(this._repository, this.streamId)
      : super(const ViewerStreamState()) {
    _init();
  }

  Future<void> _init() async {
    LiveStreamModel? doc;
    try {
      doc = await _repository.getStreamById(streamId);
    } catch (_) {}

    if (doc == null || !doc.isLive) {
      state = state.copyWith(
        isLoading: false,
        error: 'Stream not found or has ended.',
      );
      return;
    }

    state = state.copyWith(streamDoc: doc, isLoading: false, hasJoined: true);

    _streamDocSub = _repository.watchStream(streamId).listen((liveDoc) {
      if (!mounted) return;
      if (liveDoc == null || !liveDoc.isLive) {
        if (mounted) state = state.copyWith(isHostOffline: true);
      } else {
        state = state.copyWith(streamDoc: liveDoc);
      }
    });

    debugPrint('[ViewerVM] Watching stream: $streamId');
  }

  @override
  void dispose() {
    _streamDocSub?.cancel();
    super.dispose();
  }
}

final viewerStreamViewModelProvider = StateNotifierProvider.family
    .autoDispose<ViewerStreamViewModel, ViewerStreamState, String>(
  (ref, streamId) {
    final repo = ref.read(liveStreamRepositoryProvider);
    return ViewerStreamViewModel(repo, streamId);
  },
);
