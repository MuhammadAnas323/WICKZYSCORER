// Real CameraStreamingService — uses the `camera` plugin for a live preview
// and records the stream to a local file using path_provider.
// Drop in Agora / Wowza RTMP later by adding the startStream logic.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'streaming_service.dart';

/// Real camera implementation of [StreamingService].
/// Uses the `camera` package to show a live preview and record video
/// to the device's local documents directory.
class CameraStreamingService implements StreamingService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isMuted = false;
  bool _torchOn = false;
  int _cameraIndex = 0;
  DateTime? _startTime;

  @override
  Future<bool> initCamera({bool useFrontCamera = false}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;

      // Pick front or back camera
      _cameraIndex = useFrontCamera
          ? _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front)
          : _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_cameraIndex < 0) _cameraIndex = 0;

      await _initController(_cameras[_cameraIndex]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: !_isMuted,
    );
    await _controller!.initialize();
    // Apply torch state if needed
    if (_torchOn) {
      await _controller!.setFlashMode(FlashMode.torch);
    }
  }

  CameraController? get controller => _controller;

  @override
  Future<void> switchCamera() async {
    if (_cameras.isEmpty) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_cameraIndex]);
  }

  @override
  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    // Re-init to apply audio setting
    if (_controller != null && _cameras.isNotEmpty) {
      await _initController(_cameras[_cameraIndex]);
    }
    return _isMuted;
  }

  @override
  Future<bool> toggleTorch() async {
    if (_controller == null) return _torchOn;
    _torchOn = !_torchOn;
    await _controller!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    return _torchOn;
  }

  @override
  Future<void> startScreenBroadcast({required String streamKey, required String title}) async {
    // Not supported in CameraStreamingService - use AgoraService for screen broadcast
    await startStream(streamKey: streamKey, title: title);
  }

  @override
  Future<void> stopScreenCapture() async {
    // Not supported in CameraStreamingService
  }

  @override
  Future<void> startStream({required String streamKey, required String title}) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    _startTime = DateTime.now();
    // NOTE: Real RTMP push (e.g. via Agora) would start here.
    // For now we start a local video recording as the "stream".
    try {
      await _controller!.startVideoRecording();
    } catch (_) {
      // Silently ignore if recording is not supported
    }
  }

  @override
  Future<void> joinAsViewer({
    required String channelName,
    required int uid,
  }) async {
    // CameraStreamingService is only used for broadcaster preview and recording.
    // Viewer mode is not supported here, so this is a no-op.
    return;
  }

  @override
  Stream<int> get onRemoteUserJoined => const Stream<int>.empty();

  @override
  Stream<int> get onRemoteUserOffline => const Stream<int>.empty();

  @override
  Future<StreamSummary> endStream({bool saveRecording = false}) async {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;
    _startTime = null;

    bool saved = false;
    if (_controller != null && _controller!.value.isRecordingVideo) {
      try {
        final videoFile = await _controller!.stopVideoRecording();
        if (saveRecording) {
          final dir = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final destPath = path.join(dir.path, 'sportyapp_stream_$timestamp.mp4');
          await File(videoFile.path).copy(destPath);
          saved = true;
        }
      } catch (_) {}
    }

    return StreamSummary(
      duration: duration,
      peakViewers: 0,
      totalComments: 0,
      replaySaved: saved,
    );
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
