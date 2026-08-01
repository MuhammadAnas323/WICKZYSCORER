import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';
import 'package:sportyapp/data/repositories/live_stream_repository.dart';
import 'package:sportyapp/data/services/agora_rtc_service.dart';
import 'package:sportyapp/data/providers/live_providers.dart';

class ViewerStreamState {
  final bool isLoading;
  final bool hasJoinedChannel;
  final int? remoteUid;
  final bool isHostOffline;
  final LiveStreamModel? streamDoc;
  final String? error;

  const ViewerStreamState({
    this.isLoading = true,
    this.hasJoinedChannel = false,
    this.remoteUid,
    this.isHostOffline = false,
    this.streamDoc,
    this.error,
  });

  ViewerStreamState copyWith({
    bool? isLoading,
    bool? hasJoinedChannel,
    int? remoteUid,
    bool? isHostOffline,
    LiveStreamModel? streamDoc,
    String? error,
  }) =>
      ViewerStreamState(
        isLoading: isLoading ?? this.isLoading,
        hasJoinedChannel: hasJoinedChannel ?? this.hasJoinedChannel,
        remoteUid: remoteUid ?? this.remoteUid,
        isHostOffline: isHostOffline ?? this.isHostOffline,
        streamDoc: streamDoc ?? this.streamDoc,
        error: error,
      );
}

class ViewerStreamViewModel extends StateNotifier<ViewerStreamState> {
  final AgoraRtcService _agora;
  final LiveStreamRepository _repository;
  final String streamId;

  StreamSubscription<int>? _userJoinedSub;
  StreamSubscription<int>? _userOfflineSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<LiveStreamModel?>? _streamDocSub;

  ViewerStreamViewModel(this._agora, this._repository, this.streamId)
      : super(const ViewerStreamState()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Load the Firestore stream document.
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

    state = state.copyWith(streamDoc: doc);

    // 2. Watch for Firestore document changes (e.g. host ends stream).
    _streamDocSub = _repository.watchStream(streamId).listen((liveDoc) {
      if (!mounted) return;
      if (liveDoc == null || !liveDoc.isLive) {
        // Host ended the stream via the backend.
        _onHostEndedStream();
      } else {
        state = state.copyWith(streamDoc: liveDoc);
      }
    });

    // 3. Join the Agora channel as audience.
    await _joinChannel(doc);
  }

  Future<void> _joinChannel(LiveStreamModel doc) async {
    // Listen for remote user events BEFORE joining.
    _userJoinedSub = _agora.onRemoteUserJoined.listen((uid) {
      if (!mounted) return;
      debugPrint('[ViewerVM] Host detected uid=$uid');
      state = state.copyWith(remoteUid: uid, isLoading: false);
    });

    _userOfflineSub = _agora.onRemoteUserOffline.listen((uid) {
      if (!mounted) return;
      debugPrint('[ViewerVM] Host offline uid=$uid');
      state = state.copyWith(isHostOffline: true);
    });

    _errorSub = _agora.onConnectionError.listen((msg) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: msg);
    });

    // Join as audience.
    try {
      await _agora.startViewer(
        channelId: doc.channelId,
        uid: 0,
      );

      if (mounted) {
        state = state.copyWith(hasJoinedChannel: true);
        // If we joined but haven't received the host's UID yet,
        // keep isLoading true (the onUserJoined handler will flip it).
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not connect to stream: ${e.toString()}',
        );
      }
    }
  }

  /// Called when the Firestore document flips isLive to false.
  void _onHostEndedStream() {
    debugPrint('[ViewerVM] Stream ended by host');
    _cleanUp();
    if (mounted) {
      state = state.copyWith(isHostOffline: true, isLoading: false);
    }
  }

  /// Leave the Agora channel and cancel subscriptions.
  Future<void> _cleanUp() async {
    _userJoinedSub?.cancel();
    _userOfflineSub?.cancel();
    _errorSub?.cancel();
    _userJoinedSub = null;
    _userOfflineSub = null;
    _errorSub = null;

    try {
      await _agora.leaveChannel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanUp();
    _streamDocSub?.cancel();
    super.dispose();
  }
}

final viewerStreamViewModelProvider = StateNotifierProvider.family
    .autoDispose<ViewerStreamViewModel, ViewerStreamState, String>(
  (ref, streamId) {
    final agora = ref.read(agoraRtcServiceProvider);
    final repo = ref.read(liveStreamRepositoryProvider);
    return ViewerStreamViewModel(agora, repo, streamId);
  },
);
