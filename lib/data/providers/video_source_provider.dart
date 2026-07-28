import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sportyapp/data/models/video_source_model.dart';
import 'package:sportyapp/data/services/video_source_service.dart';

final videoSourceServiceProvider = Provider<VideoSourceService>((ref) {
  return VideoSourceService(FirebaseFunctions.instance);
});

final videoSourceProvider = StateNotifierProvider<VideoSourceNotifier, AsyncValue<VideoSourceSettings>>((ref) {
  final service = ref.watch(videoSourceServiceProvider);
  return VideoSourceNotifier(service);
});

class VideoSourceResultState {
  final bool isLoading;
  final VideoSourceResult? result;
  final String? error;
  final List<String> log;

  const VideoSourceResultState({
    this.isLoading = false,
    this.result,
    this.error,
    this.log = const [],
  });

  VideoSourceResultState copyWith({
    bool? isLoading,
    VideoSourceResult? result,
    String? error,
    List<String>? log,
  }) => VideoSourceResultState(
    isLoading: isLoading ?? this.isLoading,
    result: result ?? this.result,
    error: error,
    log: log ?? this.log,
  );
}

final videoSourceResultProvider = StateNotifierProvider<VideoSourceResultNotifier, VideoSourceResultState>((ref) {
  final service = ref.watch(videoSourceServiceProvider);
  return VideoSourceResultNotifier(service);
});

class VideoSourceNotifier extends StateNotifier<AsyncValue<VideoSourceSettings>> {
  final VideoSourceService _service;

  VideoSourceNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final settings = await _service.loadSettings();
    state = AsyncValue.data(settings);
  }

  Future<void> saveSettings(VideoSourceSettings settings) async {
    await _service.saveSettings(settings);
    state = AsyncValue.data(settings);
  }

  Future<void> clearSettings() async {
    await _service.clearSettings();
    state = const AsyncValue.data(VideoSourceSettings());
  }
}

class VideoSourceResultNotifier extends StateNotifier<VideoSourceResultState> {
  final VideoSourceService _service;

  VideoSourceResultNotifier(this._service) : super(const VideoSourceResultState());

  void _log(String msg) {
    state = state.copyWith(log: [...state.log, '[${DateTime.now().toString().substring(11, 19)}] $msg']);
  }

  Future<VideoSourceResult?> resolve(String url) async {
    _log('Starting resolve for: $url');
    state = state.copyWith(isLoading: true, result: null, error: null);

    try {
      final result = await _service.resolve(url);
      if (result.success) {
        _log('Success: found ${result.streams.length} stream(s)');
        for (final s in result.streams) {
          _log('  ${s.format}: ${s.url}');
        }
      } else {
        _log('Not found: ${result.message}');
      }
      state = state.copyWith(isLoading: false, result: result, error: null);
      return result;
    } on TimeoutException {
      _log('Timeout: function did not respond in time');
      state = state.copyWith(isLoading: false, error: 'Request timed out. The function may be cold-starting or the page is too slow.');
    } on FirebaseFunctionsException catch (e) {
      _log('Functions error [${e.code}]: ${e.message}');
      state = state.copyWith(isLoading: false, error: e.message ?? 'Function error: ${e.code}');
    } catch (e, st) {
      _log('Unexpected error: $e');
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
    return null;
  }

  void clearResult() {
    state = const VideoSourceResultState();
  }
}
