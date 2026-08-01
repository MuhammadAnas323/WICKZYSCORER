import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/services/agora_token_service.dart';

class AgoraRtcService {
  RtcEngine? _engine;
  final AgoraTokenService _tokenService;

  bool _isInitialized = false;
  bool _isInChannel = false;

  // Recreated before each joinChannel() call to await onJoinChannelSuccess.
  late Completer<int> _channelJoined;

  // UID assigned by Agora (0 for host when using uid=0).
  int _localUid = 0;

  // ── Public streams for remote user events ───────────────────────────────

  final StreamController<int> _onRemoteUserJoinedCtrl =
      StreamController<int>.broadcast();
  final StreamController<int> _onRemoteUserOfflineCtrl =
      StreamController<int>.broadcast();
  final StreamController<String> _onConnectionErrorCtrl =
      StreamController<String>.broadcast();

  Stream<int> get onRemoteUserJoined => _onRemoteUserJoinedCtrl.stream;
  Stream<int> get onRemoteUserOffline => _onRemoteUserOfflineCtrl.stream;
  Stream<String> get onConnectionError => _onConnectionErrorCtrl.stream;

  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  int get localUid => _localUid;

  AgoraRtcService(this._tokenService);

  /// Idempotent engine init with live broadcasting profile.
  Future<void> _ensureEngine() async {
    if (_engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(
      appId: AppConstants.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    await _engine!.enableVideo();
    await _engine!.enableAudio();
    await _engine!.enableLocalVideo(true);
    await _engine!.enableLocalAudio(true);

    _registerHandlers();
    _isInitialized = true;
    debugPrint('[AgoraRtc] Engine initialized');
  }

  /// Register all RTC event handlers.
  void _registerHandlers() {
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        final uid = connection.localUid ?? 0;
        _localUid = uid;
        _isInChannel = true;
        debugPrint('[AgoraRtc] Joined channel uid=$uid');
        if (!_channelJoined.isCompleted) _channelJoined.complete(uid);
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugPrint('[AgoraRtc] Remote user joined uid=$remoteUid');
        _onRemoteUserJoinedCtrl.add(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        debugPrint('[AgoraRtc] Remote user offline uid=$remoteUid reason=$reason');
        _onRemoteUserOfflineCtrl.add(remoteUid);
      },
      onConnectionStateChanged: (RtcConnection connection,
          ConnectionStateType state, ConnectionChangedReasonType reason) {
        debugPrint('[AgoraRtc] Connection state=$state reason=$reason');

        if (state == ConnectionStateType.connectionStateFailed) {
          final isTokenError = reason ==
                  ConnectionChangedReasonType.connectionChangedInvalidToken ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedTokenExpired;
          final msg = isTokenError
              ? 'Token error — check Agora project credentials.'
              : 'Connection failed (${reason.name}). Check your network.';

          if (!_channelJoined.isCompleted) {
            _channelJoined.completeError(Exception(msg));
          }
          _onConnectionErrorCtrl.add(msg);
        }

        if (state == ConnectionStateType.connectionStateDisconnected) {
          _isInChannel = false;
        }
      },
      onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
        _renewToken();
      },
      onError: (ErrorCodeType err, String msg) {
        debugPrint('[AgoraRtc] Error ${err.value()}: $msg');
      },
    ));
  }

  /// Renew token when privilege is about to expire.
  Future<void> _renewToken() async {
    if (_engine == null || _channelName == null) return;
    try {
      final newToken = await _tokenService.fetchToken(
        channelName: _channelName!,
        uid: _localUid,
      );
      if (newToken.isNotEmpty) {
        await _engine!.renewToken(newToken);
        debugPrint('[AgoraRtc] Token renewed');
      }
    } catch (e) {
      debugPrint('[AgoraRtc] Token renewal failed: $e');
    }
  }

  String? _channelName;

  // ── Host flow ──────────────────────────────────────────────────────────

  /// Initialize camera, join channel as broadcaster, publish video+audio.
  Future<void> startHost({
    required String channelId,
    required bool useFrontCamera,
  }) async {
    await _ensureEngine();

    _channelJoined = Completer<int>();
    _channelName = channelId;

    // 720p encoder config
    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        bitrate: 0,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
      ),
    );

    // Start local preview so the host sees their own camera.
    await _engine!.startPreview();

    // Switch to front camera if requested (default is rear).
    if (useFrontCamera) {
      await _engine!.switchCamera();
    }

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    final token = await _tokenService.fetchToken(
      channelName: channelId,
      uid: 0,
    );

    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
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

    // Confirm the channel join succeeded.
    try {
      await _channelJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Host connection timed out.'),
      );
    } catch (e) {
      await _engine!.leaveChannel();
      _isInChannel = false;
      rethrow;
    }

    // Re-enable preview after joining (some SDK versions reset the pipeline).
    await _engine!.enableVideo();
    await _engine!.enableLocalVideo(true);
    await _engine!.startPreview();

    debugPrint('[AgoraRtc] Host live on channel=$channelId');
  }

  // ── Viewer flow ────────────────────────────────────────────────────────

  /// Join a channel as audience and subscribe to the host's feed.
  Future<void> startViewer({
    required String channelId,
    int uid = 0,
  }) async {
    await _ensureEngine();

    _channelJoined = Completer<int>();
    _channelName = channelId;

    // Generate a non-zero UID to avoid collisions.
    final viewerUid =
        uid != 0 ? uid : (DateTime.now().millisecondsSinceEpoch % 99999) + 1;

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);

    final token = await _tokenService.fetchToken(
      channelName: channelId,
      uid: viewerUid,
    );

    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
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

    // Unmute remote media so the viewer receives the host's feed.
    await _engine!.muteAllRemoteAudioStreams(false);
    await _engine!.muteAllRemoteVideoStreams(false);

    // Confirm the channel join succeeded.
    try {
      await _channelJoined.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Viewer connection timed out.'),
      );
    } catch (e) {
      await _engine!.leaveChannel();
      _isInChannel = false;
      rethrow;
    }

    debugPrint('[AgoraRtc] Viewer joined channel=$channelId as uid=$viewerUid');
  }

  // ── Video view controllers ─────────────────────────────────────────────

  /// Local camera preview for the host.
  VideoViewController localViewController() {
    return VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(
        uid: 0,
        sourceType: VideoSourceType.videoSourceCameraPrimary,
      ),
    );
  }

  /// Remote host video feed for the viewer.
  VideoViewController remoteViewController(
    int remoteUid,
    String channelId,
  ) {
    return VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(
        uid: remoteUid,
        sourceType: VideoSourceType.videoSourceRemote,
      ),
      connection: RtcConnection(channelId: channelId),
    );
  }

  // ── Teardown ───────────────────────────────────────────────────────────

  /// Leave the current channel and stop preview.
  Future<void> leaveChannel() async {
    if (_engine == null) return;

    try {
      await _engine!.stopPreview();
    } catch (_) {}

    await _engine!.leaveChannel();
    _isInChannel = false;
    _channelName = null;
    debugPrint('[AgoraRtc] Left channel');
  }

  /// Full cleanup — release engine and all resources.
  @override
  Future<void> dispose() async {
    if (_engine == null) return;

    try {
      await _engine!.stopPreview();
    } catch (_) {}
    await _engine!.leaveChannel();
    await _engine!.release();
    _engine = null;
    _isInitialized = false;
    _isInChannel = false;

    await _onRemoteUserJoinedCtrl.close();
    await _onRemoteUserOfflineCtrl.close();
    await _onConnectionErrorCtrl.close();

    debugPrint('[AgoraRtc] Disposed');
  }
}
