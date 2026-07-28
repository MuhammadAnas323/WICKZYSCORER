import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/data/services/streaming_service.dart';
import 'package:sportyapp/data/repositories/streaming_repository.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'package:sportyapp/data/providers/live_streams_provider.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/providers/agora_providers.dart';

enum StreamType { camera, screenRecord }

class ActiveStreamState {
  final String? currentStreamId;
  final bool isLive;
  final bool
      isConnecting; // true while joining Agora (before onJoinChannelSuccess)
  final bool isMinimized;
  final bool isCameraInitialized;
  final bool isMuted;
  final bool isTorchOn;
  final bool isFrontCamera;
  final String title;
  final String description;
  final int viewerCount;
  final List<CommentModel> comments;
  final int durationSeconds;
  final StreamSummary? summary;
  final StreamType streamType;
  final bool saveReplay;
  final bool isPreparingScreenBroadcast;
  final bool isJoiningChannel;
  final String? connectionError;

  const ActiveStreamState({
    this.currentStreamId,
    this.isLive = false,
    this.isConnecting = false,
    this.isMinimized = false,
    this.isCameraInitialized = false,
    this.isMuted = false,
    this.isTorchOn = false,
    this.isFrontCamera = true,
    this.title = '',
    this.description = '',
    this.viewerCount = 0,
    this.comments = const [],
    this.durationSeconds = 0,
    this.summary,
    this.streamType = StreamType.camera,
    this.saveReplay = true,
    this.isPreparingScreenBroadcast = false,
    this.isJoiningChannel = false,
    this.connectionError,
  });

  ActiveStreamState copyWith({
    String? currentStreamId,
    bool? isLive,
    bool? isConnecting,
    bool? isMinimized,
    bool? isCameraInitialized,
    bool? isMuted,
    bool? isTorchOn,
    bool? isFrontCamera,
    String? title,
    String? description,
    int? viewerCount,
    List<CommentModel>? comments,
    int? durationSeconds,
    StreamSummary? summary,
    bool clearSummary = false,
    StreamType? streamType,
    bool? saveReplay,
    bool? isPreparingScreenBroadcast,
    bool? isJoiningChannel,
    String? connectionError,
  }) =>
      ActiveStreamState(
        currentStreamId: currentStreamId ?? this.currentStreamId,
        isLive: isLive ?? this.isLive,
        isConnecting: isConnecting ?? this.isConnecting,
        isMinimized: isMinimized ?? this.isMinimized,
        isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
        isMuted: isMuted ?? this.isMuted,
        isTorchOn: isTorchOn ?? this.isTorchOn,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        title: title ?? this.title,
        description: description ?? this.description,
        viewerCount: viewerCount ?? this.viewerCount,
        comments: comments ?? this.comments,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        summary: clearSummary ? null : (summary ?? this.summary),
        streamType: streamType ?? this.streamType,
        saveReplay: saveReplay ?? this.saveReplay,
        isPreparingScreenBroadcast:
            isPreparingScreenBroadcast ?? this.isPreparingScreenBroadcast,
        isJoiningChannel: isJoiningChannel ?? this.isJoiningChannel,
        connectionError: connectionError,
      );

  bool get isStreamingActive => isLive && !isMinimized;
}

class ActiveStreamController extends StateNotifier<ActiveStreamState> {
  final StreamingService _service;
  final StreamingRepository _repository;
  final LiveMatchRepository _liveRepo;
  Timer? _timer;
  StreamSubscription? _commentsSub;
  StreamSubscription? _viewersSub;
  DateTime? _streamStartedAt;

  ActiveStreamController(this._service, this._repository, this._liveRepo)
      : super(const ActiveStreamState());

  bool get hasActiveStream => state.isLive;

  void toggleSaveReplay() {
    state = state.copyWith(saveReplay: !state.saveReplay);
  }

  // ── Camera initialization ─────────────────────────────────────────────────

  Future<void> initCamera({bool useFrontCamera = true}) async {
    final ok = await _service.initCamera(useFrontCamera: useFrontCamera);
    if (!mounted) return;
    state = state.copyWith(
      isCameraInitialized: ok,
      isFrontCamera: useFrontCamera,
    );
  }

  void updateTitle(String val) => state = state.copyWith(title: val);
  void updateDescription(String val) =>
      state = state.copyWith(description: val);

  void setStreamType(StreamType t) {
    if (t == StreamType.screenRecord) {
      state = state.copyWith(streamType: t, isCameraInitialized: true);
    } else {
      state = state.copyWith(streamType: t);
      if (!state.isCameraInitialized) initCamera();
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    final mute = await _service.toggleMute();
    if (mounted) state = state.copyWith(isMuted: mute);
  }

  Future<void> toggleTorch() async {
    final torch = await _service.toggleTorch();
    if (mounted) state = state.copyWith(isTorchOn: torch);
  }

  Future<void> switchCamera() async {
    await _service.switchCamera();
    if (mounted) state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  // ── Start stream (direct launch — no title required) ─────────────────────
  //
  // This is the new flow: permissions are already granted before this is
  // called. We:
  //  1. Set isConnecting = true (shows loading overlay on the screen).
  //  2. Generate a channel name.
  //  3. Save the stream record to Firestore.
  //  4. Call _service.startStream() which:
  //       a. joins Agora as broadcaster,
  //       b. calls updateChannelMediaOptions() to publish camera + mic.
  //  5. Only set isLive = true AFTER Agora fires onJoinChannelSuccess
  //     (the service's Completer resolves when that callback fires).
  //  6. Start the timer ONLY after isLive = true.

  Future<void> startStream({String? existingMatchId}) async {
    _timer?.cancel();
    _commentsSub?.cancel();
    _viewersSub?.cancel();

    final isScreenRecord = state.streamType == StreamType.screenRecord;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final streamId = 'stream_$timestamp';
    final matchId = existingMatchId ?? 'match_$timestamp';
    final channelName = AppConstants.agoraTempToken.isNotEmpty
        ? (AppConstants.agoraTempChannelName.isNotEmpty
            ? AppConstants.agoraTempChannelName
            : 'test')
        : matchId;

    // Auto-generate title if not provided
    final autoTitle = state.title.isEmpty
        ? 'My ${isScreenRecord ? "Screen Recording" : "Live Stream"} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}'
        : state.title;

    state = state.copyWith(
      isConnecting: true,
      isJoiningChannel: true,
      isPreparingScreenBroadcast: isScreenRecord,
      title: autoTitle,
      clearSummary: true,
      isLive: false,
      currentStreamId: null,
      durationSeconds: 0,
      connectionError: null,
    );

    final stream = StreamModel(
      id: streamId,
      title: autoTitle,
      description: state.description,
      broadcasterId: 'me',
      broadcasterName: 'Me',
      broadcasterAvatar: 'https://ui-avatars.com/api/?name=Me',
      thumbnailUrl:
          'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e',
      status: StreamStatus.live,
      viewerCount: 0,
      startedAt: DateTime.now(),
      matchId: matchId,
      channelName: channelName,
      saveReplay: state.saveReplay,
      videoSourceType: isScreenRecord
          ? VideoSourceTypeEnum.screen
          : VideoSourceTypeEnum.camera,
    );

    await _performStartStream(stream, matchId, channelName, isScreenRecord);
  }

  Future<void> _performStartStream(
    StreamModel stream,
    String matchId,
    String channelName,
    bool isScreenRecord,
  ) async {
    // Persist stream to Firestore
    try {
      await _repository.addStream(stream);
      await _liveRepo.createLiveMatch(matchId);
    } catch (_) {}

    bool started = false;

    if (isScreenRecord) {
      try {
        await _service.startScreenBroadcast(
            streamKey: channelName, title: state.title);
        started = true;
      } catch (e) {
        if (mounted) {
          state = state.copyWith(
            isConnecting: false,
            isJoiningChannel: false,
            isPreparingScreenBroadcast: false,
            connectionError: e.toString(),
          );
        }
        return;
      }
    } else {
      try {
        // startStream() internally:
        //  - joins the Agora channel as broadcaster
        //  - calls updateChannelMediaOptions() to publish camera track
        //  - the Agora event handler sets _channelJoined completer on success
        await _service.startStream(streamKey: channelName, title: state.title);
        started = true;
      } catch (e) {
        if (mounted) {
          state = state.copyWith(
            isConnecting: false,
            isJoiningChannel: false,
            connectionError: e.toString(),
          );
        }
        return;
      }
    }

    if (!started || !mounted) return;

    // FIX: Set isLive = true and start timer ONLY after Agora confirms the
    // channel join (startStream() awaits the joinChannel call which internally
    // fires updateChannelMediaOptions — the stream is live at this point).
    state = state.copyWith(
      isConnecting: false,
      isJoiningChannel: false,
      isPreparingScreenBroadcast: false,
      isLive: true,
      durationSeconds: 0,
      currentStreamId: stream.id,
      connectionError: null,
    );

    _streamStartedAt = DateTime.now();

    // Start the duration timer now that we are confirmed live
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _streamStartedAt != null) {
        final elapsedSeconds =
            DateTime.now().difference(_streamStartedAt!).inSeconds;
        state = state.copyWith(durationSeconds: elapsedSeconds);
      }
    });

    // Watch comments and viewer count
    _commentsSub?.cancel();
    _commentsSub = _repository.watchComments(stream.id).listen((comment) {
      if (mounted) {
        state = state.copyWith(comments: [comment, ...state.comments]);
      }
    });

    _viewersSub?.cancel();
    _viewersSub = _repository.watchViewerCount(stream.id).listen((count) {
      if (mounted) state = state.copyWith(viewerCount: count);
    });
  }

  // ── Minimize / restore ────────────────────────────────────────────────────

  void minimizeStream() {
    if (state.isLive) {
      state = state.copyWith(isMinimized: true);
    }
  }

  void restoreStream() {
    if (state.isLive) {
      state = state.copyWith(isMinimized: false);
    }
  }

  // ── End stream ────────────────────────────────────────────────────────────

  Future<StreamSummary> endStream() async {
    _timer?.cancel();
    _commentsSub?.cancel();
    _viewersSub?.cancel();
    _streamStartedAt = null;

    final streamId = state.currentStreamId ?? 'unknown';

    if (state.streamType == StreamType.screenRecord) {
      await _service.stopScreenCapture();
    }

    StreamSummary summary =
        await _service.endStream(saveRecording: state.saveReplay);

    // Mark stream as ended in Firestore
    try {
      await _repository.removeStream(streamId);
    } catch (_) {}

    if (mounted) {
      state = state.copyWith(
        isLive: false,
        isConnecting: false,
        isMinimized: false,
        isPreparingScreenBroadcast: false,
        isJoiningChannel: false,
        summary: summary,
        currentStreamId: null,
        durationSeconds: 0,
      );
    }

    return summary;
  }

  // ── Send comment (broadcaster can comment too) ──────────────────────────

  Future<void> sendComment(String text) async {
    final streamId = state.currentStreamId;
    if (streamId == null || text.trim().isEmpty) return;
    try {
      await _repository.postComment(streamId, text.trim());
    } catch (e) {
      debugPrint('[ActiveStream] sendComment error: $e');
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    _timer?.cancel();
    _commentsSub?.cancel();
    _viewersSub?.cancel();
    _streamStartedAt = null;
    state = const ActiveStreamState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentsSub?.cancel();
    _viewersSub?.cancel();
    _streamStartedAt = null;
    _service.dispose();
    super.dispose();
  }
}

final activeStreamControllerProvider =
    StateNotifierProvider<ActiveStreamController, ActiveStreamState>((ref) {
  final repo = ref.read(streamingRepositoryProvider);
  final liveRepo = ref.read(liveMatchRepositoryProvider);
  final service = ref.read(streamingServiceProvider);
  return ActiveStreamController(service, repo, liveRepo);
});
