import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/services/agora_token_service.dart';
import 'streaming_service.dart';

enum VideoPublishSource { camera, screen, none }

class LiveStreamStats {
  final int localUid;
  final bool channelJoined;
  final int remoteUid;
  final int viewerCount;
  final int networkQuality;
  final int videoBitrate;
  final int audioBitrate;
  final int fps;
  final int packetLoss;
  final int uplinkQuality;
  final int downlinkQuality;
  final int lastErrorCode;
  final int lastWarning;
  final String channelName;
  final int streamDurationSeconds;
  final String connectionState;
  final VideoPublishSource publishSource;
  final int uplinkBitrate;
  final int downlinkBitrate;

  const LiveStreamStats({
    this.localUid = 0,
    this.channelJoined = false,
    this.remoteUid = 0,
    this.viewerCount = 0,
    this.networkQuality = 0,
    this.videoBitrate = 0,
    this.audioBitrate = 0,
    this.fps = 0,
    this.packetLoss = 0,
    this.uplinkQuality = 0,
    this.downlinkQuality = 0,
    this.lastErrorCode = 0,
    this.lastWarning = 0,
    this.channelName = '',
    this.streamDurationSeconds = 0,
    this.connectionState = 'idle',
    this.publishSource = VideoPublishSource.none,
    this.uplinkBitrate = 0,
    this.downlinkBitrate = 0,
  });

  LiveStreamStats copyWith({
    int? localUid,
    bool? channelJoined,
    int? remoteUid,
    int? viewerCount,
    int? networkQuality,
    int? videoBitrate,
    int? audioBitrate,
    int? fps,
    int? packetLoss,
    int? uplinkQuality,
    int? downlinkQuality,
    int? lastErrorCode,
    int? lastWarning,
    String? channelName,
    int? streamDurationSeconds,
    String? connectionState,
    VideoPublishSource? publishSource,
    int? uplinkBitrate,
    int? downlinkBitrate,
  }) =>
      LiveStreamStats(
        localUid: localUid ?? this.localUid,
        channelJoined: channelJoined ?? this.channelJoined,
        remoteUid: remoteUid ?? this.remoteUid,
        viewerCount: viewerCount ?? this.viewerCount,
        networkQuality: networkQuality ?? this.networkQuality,
        videoBitrate: videoBitrate ?? this.videoBitrate,
        audioBitrate: audioBitrate ?? this.audioBitrate,
        fps: fps ?? this.fps,
        packetLoss: packetLoss ?? this.packetLoss,
        uplinkQuality: uplinkQuality ?? this.uplinkQuality,
        downlinkQuality: downlinkQuality ?? this.downlinkQuality,
        lastErrorCode: lastErrorCode ?? this.lastErrorCode,
        lastWarning: lastWarning ?? this.lastWarning,
        channelName: channelName ?? this.channelName,
        streamDurationSeconds:
            streamDurationSeconds ?? this.streamDurationSeconds,
        connectionState: connectionState ?? this.connectionState,
        publishSource: publishSource ?? this.publishSource,
        uplinkBitrate: uplinkBitrate ?? this.uplinkBitrate,
        downlinkBitrate: downlinkBitrate ?? this.downlinkBitrate,
      );

  String get connectionStateLabel {
    switch (connectionState) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'disconnected':
        return 'Disconnected';
      case 'reconnecting':
        return 'Reconnecting...';
      case 'failed':
        return 'Failed';
      default:
        return 'Idle';
    }
  }

  String get publishSourceLabel {
    switch (publishSource) {
      case VideoPublishSource.camera:
        return 'Camera';
      case VideoPublishSource.screen:
        return 'Screen';
      case VideoPublishSource.none:
        return 'None';
    }
  }
}

final liveStreamStatsProvider =
    StateNotifierProvider<LiveStreamStatsNotifier, LiveStreamStats>(
  (ref) => LiveStreamStatsNotifier(),
);

class LiveStreamStatsNotifier extends StateNotifier<LiveStreamStats> {
  LiveStreamStatsNotifier() : super(const LiveStreamStats());
  void notify(LiveStreamStats stats) => state = stats;
  void update({
    int? localUid,
    bool? channelJoined,
    int? remoteUid,
    int? viewerCount,
    int? networkQuality,
    int? videoBitrate,
    int? audioBitrate,
    int? fps,
    int? packetLoss,
    int? uplinkQuality,
    int? downlinkQuality,
    int? lastErrorCode,
    int? lastWarning,
    String? channelName,
    int? streamDurationSeconds,
    String? connectionState,
    VideoPublishSource? publishSource,
    int? uplinkBitrate,
    int? downlinkBitrate,
  }) {
    state = state.copyWith(
      localUid: localUid,
      channelJoined: channelJoined,
      remoteUid: remoteUid,
      viewerCount: viewerCount,
      networkQuality: networkQuality,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      fps: fps,
      packetLoss: packetLoss,
      uplinkQuality: uplinkQuality,
      downlinkQuality: downlinkQuality,
      lastErrorCode: lastErrorCode,
      lastWarning: lastWarning,
      channelName: channelName,
      streamDurationSeconds: streamDurationSeconds,
      connectionState: connectionState,
      publishSource: publishSource,
      uplinkBitrate: uplinkBitrate,
      downlinkBitrate: downlinkBitrate,
    );
  }

  void reset() => state = const LiveStreamStats();
}

// ---------------------------------------------------------------------------
// AgoraService — complete, fixed implementation
// ---------------------------------------------------------------------------
// ROOT CAUSE FIXES:
//  1. initCamera() now calls engine.startPreview() so the local view renders.
//  2. startStream() calls updateChannelMediaOptions() after joinChannel() to
//     explicitly confirm publishCameraTrack=true (required by Agora SDK v6).
//  3. joinAsViewer() uses a random non-zero UID so it doesn't clash with the
//     broadcaster's UID=0.
//  4. remoteViewController() passes VideoSourceType.videoSourceRemote for
//     camera streams so the remote AgoraVideoView renders correctly.
//  5. enableLocalVideo(true) and enableLocalAudio(true) are called on engine
//     initialization to ensure video/audio pipelines are active.
// ---------------------------------------------------------------------------

class AgoraService implements StreamingService {
  RtcEngine? _engine;
  final AgoraTokenService _tokenService;
  String? _channelName;
  bool _isMuted = false;
  bool _isScreenCapturing = false;
  bool _cameraPreviewActive = false;
  bool _handlersRegistered = false;

  /// Tracks active camera direction (defaults to true for front camera on startPreview).
  bool _isFrontCamera = true;

  /// Tracks whether we have successfully joined a channel (broadcaster OR viewer).
  bool _isInChannel = false;

  /// Completer that resolves with the local UID when onJoinChannelSuccess fires.
  Completer<int> _channelJoined = Completer<int>();

  DateTime? _streamStartTime;

  /// Current camera zoom factor (1.0 = no zoom).
  double _currentZoom = 1.0;
  double get currentZoom => _currentZoom;

  final StreamController<int> _remoteUserController =
      StreamController<int>.broadcast();
  final StreamController<int> _userOfflineController =
      StreamController<int>.broadcast();
  final StreamController<String> _connectionErrorController =
      StreamController<String>.broadcast();

  @override
  Stream<int> get onRemoteUserJoined => _remoteUserController.stream;
  @override
  Stream<int> get onRemoteUserOffline => _userOfflineController.stream;

  /// Emits a human-readable error message when the Agora channel join fails
  /// (e.g. invalid token, network failure). Subscribe in the viewer to show
  /// a proper error state instead of an infinite loading spinner.
  Stream<String> get onConnectionError => _connectionErrorController.stream;

  RtcEngine? get engine => _engine;
  bool get isInitialized => _engine != null;
  bool get isInChannel => _isInChannel;
  bool get isScreenCapturing => _isScreenCapturing;

  AgoraService(this._tokenService);

  LiveStreamStatsNotifier? _statsNotifier;
  void attachStats(LiveStreamStatsNotifier notifier) {
    _statsNotifier = notifier;
  }

  // ── Engine initialization ─────────────────────────────────────────────────

  Future<void> _initEngine() async {
    if (_engine != null) {
      if (!_handlersRegistered) _registerHandlers();
      return;
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AppConstants.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Explicitly enable video and audio pipelines on init.
    await _engine!.enableVideo();
    await _engine!.enableAudio();
    await _engine!.enableLocalVideo(true);
    await _engine!.enableLocalAudio(true);

    _registerHandlers();
  }

  // ── Camera initialization (broadcaster) ───────────────────────────────────

  @override
  Future<bool> initCamera({bool useFrontCamera = true}) async {
    try {
      await _initEngine();

      // Set video encoder configuration for good quality
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 30,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      // FIX #1: Call startPreview() so the local AgoraVideoView renders.
      // Without this call, the camera viewport stays black for both
      // the local preview AND the remote viewer.
      await _engine!.startPreview();
      _cameraPreviewActive = true;

      // Only switch camera if current active camera does not match requested camera
      if (_isFrontCamera != useFrontCamera) {
        await _engine!.switchCamera();
        _isFrontCamera = useFrontCamera;
      }

      debugPrint(
          '[Agora] initCamera: preview started, useFrontCamera=$useFrontCamera');
      return true;
    } catch (e) {
      debugPrint('[Agora] initCamera error: $e');
      return false;
    }
  }

  // ── Event handlers ────────────────────────────────────────────────────────

  void _registerHandlers() {
    _handlersRegistered = true;
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        final uid = connection.localUid ?? 0;
        debugPrint(
            '[Agora] onJoinChannelSuccess: uid=$uid, channel=${connection.channelId}, elapsed=${elapsed}ms');
        _isInChannel = true;
        if (!_channelJoined.isCompleted) {
          _channelJoined.complete(uid);
        }
        _updateStats(
          localUid: uid,
          channelJoined: true,
          channelName: connection.channelId ?? '',
          connectionState: 'connected',
        );
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        debugPrint('[Agora] onLeaveChannel: channel=${connection.channelId}');
        _isInChannel = false;
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint(
            '[Agora] onUserJoined: remoteUid=$remoteUid, channel=${connection.channelId}');
        _remoteUserController.add(remoteUid);
        _updateStats(remoteUid: remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint(
            '[Agora] onUserOffline: remoteUid=$remoteUid, reason=$reason');
        _userOfflineController.add(remoteUid);
      },
      onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid,
          int width, int height, int elapsed) {
        debugPrint(
            '[Agora] onFirstRemoteVideoFrame: uid=$remoteUid, ${width}x$height, elapsed=${elapsed}ms');
        _remoteUserController.add(remoteUid);
      },
      onFirstRemoteVideoDecoded: (RtcConnection connection, int remoteUid,
          int width, int height, int elapsed) {
        debugPrint(
            '[Agora] onFirstRemoteVideoDecoded: uid=$remoteUid, ${width}x$height');
      },
      onVideoPublishStateChanged: (VideoSourceType sourceType,
          String channel,
          StreamPublishState oldState,
          StreamPublishState newState,
          int elapseSinceLastState) {
        debugPrint(
            '[Agora] onVideoPublishStateChanged: source=$sourceType, $oldState -> $newState');
      },
      onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid,
          RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
        debugPrint(
            '[Agora] onRemoteVideoStateChanged: uid=$remoteUid, state=$state, reason=$reason');
        if (state == RemoteVideoState.remoteVideoStateStarting ||
            state == RemoteVideoState.remoteVideoStateDecoding) {
          _remoteUserController.add(remoteUid);
        }
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        debugPrint('[Agora] onTokenPrivilegeWillExpire');
        _refreshToken(token);
      },
      onRtcStats: (RtcConnection connection, RtcStats stats) {
        _updateStats(
          videoBitrate: stats.txVideoKBitRate ?? 0,
          audioBitrate: stats.txAudioKBitRate ?? 0,
          packetLoss: stats.txPacketLossRate ?? 0,
          streamDurationSeconds: stats.duration ?? 0,
          viewerCount: stats.userCount ?? 0,
          uplinkBitrate:
              (stats.txVideoKBitRate ?? 0) + (stats.txAudioKBitRate ?? 0),
          downlinkBitrate:
              (stats.rxVideoKBitRate ?? 0) + (stats.rxAudioKBitRate ?? 0),
        );
      },
      onNetworkQuality: (RtcConnection connection, int remoteUid,
          QualityType txQuality, QualityType rxQuality) {
        _updateStats(
          networkQuality: txQuality.index,
          uplinkQuality: txQuality.index,
          downlinkQuality: rxQuality.index,
        );
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('[Agora] onError: code=${err.value()}, msg=$msg');
        _updateStats(lastErrorCode: err.value());
      },
      onLocalVideoStats: (RtcConnection connection, VideoSourceType sourceType,
          LocalVideoStats stats) {
        _updateStats(
          fps: stats.sentFrameRate ?? 0,
          videoBitrate: stats.sentBitrate ?? 0,
        );
      },
      onLocalAudioStats: (RtcConnection connection, LocalAudioStats stats) {
        _updateStats(audioBitrate: stats.sentBitrate ?? 0);
      },
      onRemoteVideoStats: (RtcConnection connection, RemoteVideoStats stats) {
        _updateStats(
          fps: stats.decoderOutputFrameRate ??
              stats.rendererOutputFrameRate ??
              0,
          downlinkBitrate: stats.receivedBitrate ?? 0,
        );
      },
      onRemoteAudioStats: (RtcConnection connection, RemoteAudioStats stats) {
        _updateStats(
          audioBitrate: stats.receivedBitrate ?? 0,
          packetLoss: stats.audioLossRate ?? 0,
        );
      },
      onLastmileQuality: (QualityType quality) {
        _updateStats(networkQuality: quality.index);
      },
      onClientRoleChanged: (RtcConnection connection, ClientRoleType oldRole,
          ClientRoleType newRole, ClientRoleOptions newRoleOptions) {
        debugPrint(
            '[Agora] onClientRoleChanged: ${oldRole.name} -> ${newRole.name}');
      },
      onConnectionStateChanged: (RtcConnection connection,
          ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint(
            '[Agora] onConnectionStateChanged: state=$state, reason=$reason');
        String label;
        switch (state) {
          case ConnectionStateType.connectionStateConnected:
            label = 'connected';
            break;
          case ConnectionStateType.connectionStateConnecting:
            label = 'connecting';
            break;
          case ConnectionStateType.connectionStateDisconnected:
            label = 'disconnected';
            break;
          case ConnectionStateType.connectionStateReconnecting:
            label = 'reconnecting';
            break;
          case ConnectionStateType.connectionStateFailed:
            label = 'failed';
            // ── Emit human-readable error so the viewer UI can react ──────────
            final isTokenError = reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidToken ||
                reason ==
                    ConnectionChangedReasonType.connectionChangedTokenExpired;
            final errorMsg = isTokenError
                ? 'Stream token error — your Agora project requires a security token (Error 110). '
                    'Set project to "Testing Mode" in Agora Console (disable App Certificate) '
                    'or deploy generateAgoraToken Cloud Function.'
                : 'Could not connect to the stream (reason: ${reason.name}). '
                    'Check your internet connection and try again.';

            if (!_channelJoined.isCompleted) {
              _channelJoined.completeError(Exception(errorMsg));
            }
            if (!_connectionErrorController.isClosed) {
              _connectionErrorController.add(errorMsg);
            }
            break;
        }
        _updateStats(connectionState: label);
      },
      onRejoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugPrint('[Agora] onRejoinChannelSuccess: elapsed=${elapsed}ms');
        _updateStats(channelJoined: true, connectionState: 'connected');
      },
    ));
  }

  // ── Stats helper ──────────────────────────────────────────────────────────

  void _updateStats({
    int? localUid,
    bool? channelJoined,
    int? remoteUid,
    int? viewerCount,
    int? networkQuality,
    int? videoBitrate,
    int? audioBitrate,
    int? fps,
    int? packetLoss,
    int? uplinkQuality,
    int? downlinkQuality,
    int? lastErrorCode,
    int? lastWarning,
    String? channelName,
    int? streamDurationSeconds,
    String? connectionState,
    VideoPublishSource? publishSource,
    int? uplinkBitrate,
    int? downlinkBitrate,
  }) {
    if (_statsNotifier == null) return;
    _statsNotifier!.update(
      localUid: localUid,
      channelJoined: channelJoined,
      remoteUid: remoteUid,
      viewerCount: viewerCount,
      networkQuality: networkQuality,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      fps: fps,
      packetLoss: packetLoss,
      uplinkQuality: uplinkQuality,
      downlinkQuality: downlinkQuality,
      lastErrorCode: lastErrorCode,
      lastWarning: lastWarning,
      channelName: channelName,
      streamDurationSeconds: streamDurationSeconds,
      connectionState: connectionState,
      publishSource: publishSource,
      uplinkBitrate: uplinkBitrate,
      downlinkBitrate: downlinkBitrate,
    );
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  Future<void> _refreshToken(String? currentToken) async {
    if (_channelName == null || _engine == null) return;
    try {
      final newToken = await _tokenService.fetchToken(
        channelName: _channelName!,
        uid: 0,
      );
      // Only renew if we got a non-empty token different from current.
      if (newToken.isNotEmpty && newToken != currentToken) {
        debugPrint('[Agora] Renewing token...');
        await _engine!.renewToken(newToken);
      }
    } catch (e) {
      debugPrint('[Agora] Token refresh failed: $e');
    }
  }

  // ── updateChannelMediaOptions helper ─────────────────────────────────────

  Future<void> updateChannelMediaOptions(ChannelMediaOptions options) async {
    if (_engine == null) throw StateError('Engine not initialized');
    debugPrint(
        '[Agora] updateChannelMediaOptions: camera=${options.publishCameraTrack}, '
        'screenCaptureVideo=${options.publishScreenCaptureVideo}');
    await _engine!.updateChannelMediaOptions(options);
  }

  // ── Camera controls ───────────────────────────────────────────────────────

  @override
  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    _isFrontCamera = !_isFrontCamera;
    // Reset zoom when switching camera
    _currentZoom = 1.0;
  }

  @override
  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    await _engine?.muteLocalAudioStream(_isMuted);
    return _isMuted;
  }

  @override
  Future<bool> toggleTorch() async {
    return false; // Hardware torch toggle not universally supported via Agora
  }

  /// Sets the camera zoom factor. Clamps value between 1.0 and [maxZoom].
  Future<double> setZoom(double zoom, {double maxZoom = 5.0}) async {
    if (_engine == null) return _currentZoom;
    final clamped = zoom.clamp(1.0, maxZoom);
    try {
      await _engine!.setCameraZoomFactor(clamped);
      _currentZoom = clamped;
      debugPrint('[Agora] setZoom: $_currentZoom');
    } catch (e) {
      debugPrint('[Agora] setZoom error: $e');
    }
    return _currentZoom;
  }

  // ── Start camera live stream (broadcaster) ────────────────────────────────

  @override
  Future<void> startStream({
    required String streamKey,
    required String title,
  }) async {
    if (_engine == null) {
      throw StateError('Engine not initialized. Call initCamera() first.');
    }

    _channelName = streamKey;
    _streamStartTime = DateTime.now();
    _channelJoined = Completer<int>();

    debugPrint('[Agora] Starting camera stream: channel=$streamKey');

    // Set broadcaster role before joining
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    final token = await _tokenService.fetchToken(
      channelName: streamKey,
      uid: 0,
    );

    // Join channel as broadcaster with camera + mic publishing
    await _engine!.joinChannel(
      token: token,
      channelId: streamKey,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    // FIX #2: After joinChannel(), call updateChannelMediaOptions() to
    // explicitly re-confirm publishing settings.
    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        publishScreenCaptureVideo: false,
        publishScreenCaptureAudio: false,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    // CRITICAL FIX: Await confirmation of actual network connection to Agora servers!
    // Awaiting joinChannel() only waits for native API invocation.
    // If the token is invalid (code 110), Agora rejects the connection asynchronously.
    try {
      await _channelJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Stream connection timed out.'),
      );
    } catch (e) {
      debugPrint('[Agora] startStream network connection failed: $e');
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      _isInChannel = false;
      throw Exception(
        e.toString().replaceAll('Exception: ', ''),
      );
    }

    // FIX: Re-enable video pipeline and restart preview after joinChannel().
    // On Android, joinChannel() resets the native camera capture session.
    // Calling startPreview() here ensures the local camera viewport continues
    // streaming 30 FPS video without freezing into a static "photo" frame.
    await _engine!.enableVideo();
    await _engine!.enableLocalVideo(true);
    await _engine!.startPreview();
    _cameraPreviewActive = true;

    _updateStats(
      channelName: streamKey,
      channelJoined: true,
      localUid: 0,
      publishSource: VideoPublishSource.camera,
    );
    debugPrint(
        '[Agora] startStream: joined and preview streaming continuously');
  }

  // ── Start screen broadcast ────────────────────────────────────────────────

  @override
  Future<void> startScreenBroadcast({
    required String streamKey,
    required String title,
  }) async {
    await _initEngine();

    if (_cameraPreviewActive) {
      await _engine!.stopPreview();
      _cameraPreviewActive = false;
    }

    _isScreenCapturing = true;
    _channelName = streamKey;
    _streamStartTime = DateTime.now();
    _channelJoined = Completer<int>();

    debugPrint('[Agora] Starting screen broadcast: channel=$streamKey');

    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 1280, height: 720),
        frameRate: 15,
        bitrate: 0,
      ),
    );

    final token =
        await _tokenService.fetchToken(channelName: streamKey, uid: 0);

    await _engine!.joinChannel(
      token: token,
      channelId: streamKey,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    await _engine!.startScreenCapture(
      const ScreenCaptureParameters2(
        captureAudio: true,
        captureVideo: true,
        videoParams: ScreenVideoParameters(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 15,
          contentHint: VideoContentHint.contentHintMotion,
        ),
      ),
    );

    await _engine!.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
        publishScreenCaptureAudio: true,
        publishScreenCaptureVideo: true,
      ),
    );

    try {
      await _channelJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw Exception('Screen broadcast connection timed out.'),
      );
    } catch (e) {
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      _isInChannel = false;
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }

    _updateStats(
      channelName: streamKey,
      channelJoined: true,
      localUid: 0,
      publishSource: VideoPublishSource.screen,
    );
  }

  @override
  Future<void> stopScreenCapture() async {
    debugPrint('[Agora] stopScreenCapture');
    try {
      await _engine?.stopScreenCapture();
    } catch (_) {}
    _isScreenCapturing = false;
  }

  // ── Join as audience (viewer) ─────────────────────────────────────────────

  @override
  Future<void> joinAsViewer({
    required String channelName,
    required int uid,
  }) async {
    // ─── FIX: -17 ERR_JOIN_CHANNEL_REJECTED ──────────────────────────────────
    // Always leave any existing channel and fully release + re-create the engine
    // before joining as viewer.
    if (_engine != null) {
      debugPrint('[Agora] joinAsViewer: releasing engine for clean re-init...');
      try {
        await _engine!.leaveChannel();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
      _handlersRegistered = false;
      _isInChannel = false;
      _cameraPreviewActive = false;
      _isFrontCamera = true;
      debugPrint('[Agora] joinAsViewer: engine released, re-initializing...');
    }

    await _initEngine();

    _channelJoined = Completer<int>();
    _channelName = channelName;

    final viewerUid =
        uid != 0 ? uid : (DateTime.now().millisecondsSinceEpoch % 99999) + 1;

    debugPrint(
        '[Agora] Joining as viewer: channel=$channelName, uid=$viewerUid');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

    final token = await _tokenService.fetchToken(
      channelName: channelName,
      uid: viewerUid,
    );

    debugPrint(
        '[Agora] joinAsViewer: calling joinChannel with token="${token.isEmpty ? "(empty/testing-mode)" : "***"}"');

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: viewerUid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    // Await confirmation of actual network connection as viewer!
    try {
      await _channelJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Viewer connection timed out.'),
      );
    } catch (e) {
      debugPrint('[Agora] joinAsViewer network connection failed: $e');
      try {
        await _engine!.leaveChannel();
      } catch (_) {}
      _isInChannel = false;
      throw Exception(
        e.toString().replaceAll('Exception: ', ''),
      );
    }

    debugPrint('[Agora] joinAsViewer: channel joined as viewer uid=$viewerUid');
  }

  // ── Video view controllers ────────────────────────────────────────────────

  /// Returns a VideoViewController for the local camera preview (broadcaster).
  VideoViewController localViewController() {
    return VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(
        uid: 0,
        sourceType: VideoSourceType.videoSourceCameraPrimary,
      ),
    );
  }

  /// Returns a VideoViewController for a remote user's camera feed (viewer).
  ///
  /// FIX #4: Pass [VideoSourceType.videoSourceRemote] for camera streams so
  /// the Agora SDK correctly identifies the remote video source and renders it.
  /// Previously passing null caused the remote view to show black.
  VideoViewController remoteViewController(
    int uid,
    String channelName, {
    VideoSourceType? sourceType,
  }) {
    return VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(
        uid: uid,
        // FIX: Explicitly specify remote source type for camera feeds
        sourceType: sourceType ?? VideoSourceType.videoSourceRemote,
      ),
      connection: RtcConnection(channelId: channelName),
    );
  }

  // ── End stream ────────────────────────────────────────────────────────────

  @override
  Future<StreamSummary> endStream({bool saveRecording = false}) async {
    debugPrint('[Agora] endStream');

    if (_isScreenCapturing) {
      await stopScreenCapture();
    }

    if (_cameraPreviewActive) {
      try {
        await _engine?.stopPreview();
        _cameraPreviewActive = false;
      } catch (_) {}
    }

    if (_engine != null) {
      await _engine!.leaveChannel();
    }

    _statsNotifier?.reset();

    final duration = _streamStartTime != null
        ? DateTime.now().difference(_streamStartTime!)
        : Duration.zero;
    _streamStartTime = null;

    return StreamSummary(
      duration: duration,
      peakViewers: 0,
      totalComments: 0,
      replaySaved: false,
      endedAt: DateTime.now(),
    );
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    debugPrint('[Agora] dispose');
    if (_cameraPreviewActive) {
      try {
        await _engine?.stopPreview();
      } catch (_) {}
      _cameraPreviewActive = false;
    }
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _handlersRegistered = false;
  }
}
