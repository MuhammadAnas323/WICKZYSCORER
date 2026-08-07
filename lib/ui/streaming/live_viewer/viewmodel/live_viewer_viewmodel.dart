import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/repositories/streaming_repository.dart';
import 'package:sportyapp/data/providers/live_streams_provider.dart';

class LiveViewerState {
  final bool isLoading;
  final String? error;
  final StreamModel? stream;
  final List<CommentModel> comments;
  final bool isFollowing;

  const LiveViewerState({
    this.isLoading = true,
    this.error,
    this.stream,
    this.comments = const [],
    this.isFollowing = false,
  });

  LiveViewerState copyWith({
    bool? isLoading,
    String? error,
    StreamModel? stream,
    List<CommentModel>? comments,
    bool? isFollowing,
  }) =>
      LiveViewerState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        stream: stream ?? this.stream,
        comments: comments ?? this.comments,
        isFollowing: isFollowing ?? this.isFollowing,
      );
}

class LiveViewerViewModel extends StateNotifier<LiveViewerState> {
  final StreamingRepository _repository;
  final String streamId;

  StreamSubscription? _commentsSub;
  StreamSubscription? _viewersSub;

  LiveViewerViewModel(this._repository, this.streamId)
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
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
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
    super.dispose();
  }
}

final liveViewerViewModelProvider = StateNotifierProvider.family
    .autoDispose<LiveViewerViewModel, LiveViewerState, String>((ref, id) {
  final repo = ref.read(streamingRepositoryProvider);
  return LiveViewerViewModel(repo, id);
});
