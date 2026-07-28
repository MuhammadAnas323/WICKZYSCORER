abstract class StreamingService {
  Future<bool> initCamera({bool useFrontCamera = false});

  Future<void> switchCamera();

  Future<bool> toggleMute();

  Future<bool> toggleTorch();

  Future<void> startStream({required String streamKey, required String title});

  Future<void> startScreenBroadcast(
      {required String streamKey, required String title});

  Future<void> stopScreenCapture();

  Future<void> joinAsViewer({
    required String channelName,
    required int uid,
  });

  Stream<int> get onRemoteUserJoined;

  Stream<int> get onRemoteUserOffline;

  Future<StreamSummary> endStream({bool saveRecording = false});

  Future<void> dispose();
}

class StreamSummary {
  final Duration duration;
  final int peakViewers;
  final int totalComments;
  final bool replaySaved;
  final DateTime endedAt;

  const StreamSummary({
    required this.duration,
    required this.peakViewers,
    required this.totalComments,
    required this.replaySaved,
    required this.endedAt,
  });
}
