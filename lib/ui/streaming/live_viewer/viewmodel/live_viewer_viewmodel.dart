import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/repositories/streaming_repository.dart';
import 'package:sportyapp/data/providers/live_streams_provider.dart';
import 'package:sportyapp/data/services/agora_service.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/providers/agora_providers.dart';

class LiveViewerState {
  final bool isLoading;
  final String? error;
  final StreamModel? stream;
  final List<CommentModel> comments;
  final bool isFollowing;
  final bool hasJoinedAgora;
  final List<int> remoteUids;
  final bool isReconnecting;

  const LiveViewerState({
    this.isLoading = true,
    this.error,
    this.stream,
    this.comments = const [],
    this.isFollowing = false,
    this.hasJoinedAgora = false,
    this.remoteUids = const [],
    this.isReconnecting = false,
  });

  LiveViewerState copyWith({
    bool? isLoading,
    String? error,
    StreamModel? stream,
    List<CommentModel>? comments,
    bool? isFollowing,
    bool? hasJoinedAgora,
    List<int>? remoteUids,
    bool? isReconnecting,
  }) => LiveViewerState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    stream: stream ?? this.stream,
    comments: comments ?? this.comments,
    isFollowing: isFollowing ?? this.isFollowing,
    hasJoinedAgora: hasJoinedAgora ?? this.hasJoinedAgora,
    remoteUids: remoteUids ?? this.remoteUids,
    isReconnecting: isReconnecting ?? this.isReconnecting,
  );
}

class LiveViewerViewModel extends StateNotifier<LiveViewerState> {
  final StreamingRepository _repository;
  final AgoraService _agoraService;
  final String streamId;

  StreamSubscription? _commentsSub;
  StreamSubscription? _viewersSub;
  StreamSubscription<int>? _agoraUserJoinedSub;
  StreamSubscription<int>? _agoraUserOfflineSub;
  StreamSubscription<String>? _connectionErrorSub;

  LiveViewerViewModel(this._repository, this._agoraService, this.streamId)
      : super(const LiveViewerState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final s = await _repository.getStreamById(streamId);
      if (s == null) throw Exception('Stream not found or has ended.');

      final initialComments = await _repository.getCommentsForStream(streamId);
      state = state.copyWith(
        isLoading: false,
        stream: s,
        comments: initialComments,
      );

      _commentsSub = _repository.watchComments(streamId).listen((comment) {
        if (mounted) {
          state = state.copyWith(comments: [comment, ...state.comments]);
        }
      });

      _viewersSub = _repository.watchViewerCount(streamId).listen((count) {
        if (mounted && state.stream != null) {
          state = state.copyWith(
            stream: state.stream!.copyWith(viewerCount: count),
          );
        }
      });

      if (s.channelName != null && s.channelName!.isNotEmpty) {
        final channelToJoin = AppConstants.agoraTempToken.isNotEmpty
            ? (AppConstants.agoraTempChannelName.isNotEmpty ? AppConstants.agoraTempChannelName : 'test')
            : s.channelName!;
        await _joinAgora(channelToJoin);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> _joinAgora(String channelName) async {
    try {
      final Set<int> seenUids = {};

      // Listen for the broadcaster joining/leaving
      _agoraUserJoinedSub = _agoraService.onRemoteUserJoined.listen((uid) {
        if (mounted) {
          seenUids.add(uid);
          state = state.copyWith(
            remoteUids: seenUids.toList(),
            isReconnecting: false,
          );
        }
      });

      _agoraUserOfflineSub = _agoraService.onRemoteUserOffline.listen((uid) {
        if (mounted) {
          seenUids.remove(uid);
          state = state.copyWith(
            remoteUids: seenUids.toList(),
            // If broadcaster left, show reconnecting state
            isReconnecting: seenUids.isEmpty,
          );
        }
      });

      // ── Connection error listener (token / network failures) ─────────────
      // Fires when Agora reports connectionStateFailed so we surface a clear
      // error message instead of leaving the user on an infinite spinner.
      if (_agoraService is AgoraService) {
        _connectionErrorSub = (_agoraService as AgoraService)
            .onConnectionError
            .listen((String errMsg) {
          if (mounted) {
            state = state.copyWith(
              isLoading: false,
              error: errMsg,
            );
          }
        });
      }

      // FIX: Pass uid=0 here — the service will generate a proper non-zero UID
      await _agoraService.joinAsViewer(
        channelName: channelName,
        uid: 0, // service converts 0 to a random non-zero uid
      );

      if (mounted) {
        state = state.copyWith(hasJoinedAgora: true);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          error: 'Could not connect to live stream: ${e.toString()}',
        );
      }
    }
  }

  void toggleFollow() {
    if (mounted) {
      state = state.copyWith(isFollowing: !state.isFollowing);
    }
  }

  Future<void> sendComment(String text) async {
    if (text.trim().isEmpty) return;
    final newComment = CommentModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user_me',
      username: 'You',
      avatarUrl: 'https://picsum.photos/seed/me/50',
      text: text,
      timestamp: DateTime.now(),
    );
    if (mounted) {
      state = state.copyWith(comments: [newComment, ...state.comments]);
    }
    await _repository.postComment(streamId, text);
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    _viewersSub?.cancel();
    _agoraUserJoinedSub?.cancel();
    _agoraUserOfflineSub?.cancel();
    _connectionErrorSub?.cancel();
    super.dispose();
  }
}

final liveViewerViewModelProvider = StateNotifierProvider.family
    .autoDispose<LiveViewerViewModel, LiveViewerState, String>((ref, id) {
  final repo = ref.read(streamingRepositoryProvider);
  final agora = ref.read(agoraServiceProvider);
  return LiveViewerViewModel(repo, agora, id);
});
