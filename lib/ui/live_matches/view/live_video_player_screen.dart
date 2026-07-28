import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:sportyapp/data/providers/admin_settings_provider.dart';
import 'package:sportyapp/core/utils/stream_url_validator.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
class LiveVideoPlayerScreen extends ConsumerStatefulWidget {
  final String? url;
  final String? title;
  const LiveVideoPlayerScreen({super.key, this.url, this.title});

  @override
  ConsumerState<LiveVideoPlayerScreen> createState() => _LiveVideoPlayerScreenState();
}

class _LiveVideoPlayerScreenState extends ConsumerState<LiveVideoPlayerScreen> {
  VideoPlayerController? _controller;
  VideoPlayerController? _audioController;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _hasBuffered = false;
  String? _error;
  StreamFormat _detectedFormat = StreamFormat.unknown;
  String _loadLog = '';
  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.url ?? ref.read(adminSettingsProvider).valueOrNull?.videoUrl ?? '';

    _log('Video URL: $url');

    if (url.isEmpty) {
      _setError('No video source configured.');
      return;
    }

    final validation = StreamUrlValidator.validate(url);
    if (!validation.isValid) {
      _log('Validation failed: ${validation.error}');
      _setError(validation.error!);
      return;
    }

    if (validation.extension != null) {
      _detectedFormat = StreamUrlValidator.detectFormat(url);
      _log('Detected format: ${StreamUrlValidator.formatLabel(_detectedFormat)} ($url)');
    }

    try {
      _log('Initializing VideoPlayerController...');
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));

      _controller!.addListener(_onPlayerStateChanged);

      await _controller!.initialize().timeout(const Duration(seconds: 30));
      _log('Player initialized. Duration: ${_controller!.value.duration}');
      _controller!.play();
      _isPlaying = true;

      if (mounted) setState(() => _initialized = true);
    } on TimeoutException {
      _log('TimeoutException: player initialization timed out');
      _setError('Stream unavailable — connection timed out');
    } on SocketException catch (e) {
      _log('SocketException: ${e.message}');
      _setError('Network error — could not reach the stream source');
    } on HttpException catch (e) {
      _log('HttpException: ${e.message}');
      _setError('Stream unavailable — HTTP error');
    } on FormatException catch (e) {
      _log('FormatException: ${e.message}');
      _setError('Invalid stream URL');
    } catch (e) {
      _log('Exception: $e');
      final msg = e.toString();
      if (msg.contains('Source error') || msg.contains('ExoPlaybackException')) {
        _setError('Unsupported video source or invalid stream URL');
      } else if (msg.contains('IOError') || msg.contains('Connection')) {
        _setError('Network error — unable to load stream');
      } else {
        _setError('Stream unavailable');
      }
    }
  }

  void _onPlayerStateChanged() {
    if (_controller == null) return;
    final value = _controller!.value;

    if (value.isBuffering && !_hasBuffered) {
      _log('Buffering...');
    }
    if (value.hasError) {
      _log('Player error: ${value.errorDescription}');
      if (_error == null && mounted) {
        setState(() => _error = 'Playback failed');
      }
    }
    if (value.position > Duration.zero && !_hasBuffered) {
      _hasBuffered = true;
      _log('Playback started at position: ${value.position}');
    }
    if (mounted) {
      setState(() => _isPlaying = value.isPlaying);
    }
  }

  void _log(String msg) {
    _loadLog += '$msg\n';
  }

  void _setError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    _audioController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(adminSettingsProvider).valueOrNull;
    final matchName = widget.title ?? settings?.videoMatchName ?? 'Live Match';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(matchName),
        backgroundColor: Colors.black,
        actions: [
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _error = null;
                  _initialized = false;
                  _loadLog = '';
                });
                _controller?.removeListener(_onPlayerStateChanged);
                _controller?.dispose();
                _controller = null;
                _initPlayer();
              },
            ),
        ],
      ),
      body: _buildBody(cs, matchName),
    );
  }

  Widget _buildBody(ColorScheme cs, String matchName) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Cannot play video',
                style: AppTextStyles.titleLarge(Colors.white)),
              const SizedBox(height: 8),
              Text(_error!,
                style: AppTextStyles.bodyMedium(Colors.white54),
                textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pitchGreenLight,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () {
                  setState(() {
                    _error = null;
                    _initialized = false;
                    _loadLog = '';
                  });
                  _controller?.removeListener(_onPlayerStateChanged);
                  _controller?.dispose();
                  _controller = null;
                  _initPlayer();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(color: Colors.white),
            ),
            SizedBox(height: 16),
            Text('Loading video...', style: TextStyle(color: Colors.white54)),
            SizedBox(height: 8),
            Text('Connecting to stream source',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Video player
        Expanded(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller!),
                    if (!_isPlaying)
                      Center(
                        child: Container(
                          width: 64, height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                        ),
                      ),
                    if (_controller!.value.isBuffering)
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Controls overlay
        Container(
          color: Colors.grey[950],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _togglePlayPause,
              ),
              Expanded(
                child: _controller!.value.isInitialized
                    ? VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppColors.pitchGreenLight,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                      )
                    : const SizedBox(),
              ),
              if (_detectedFormat != StreamFormat.unknown)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pitchGreenLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.5)),
                  ),
                  child: Text(
                    StreamUrlValidator.formatLabel(_detectedFormat),
                    style: const TextStyle(
                      color: AppColors.pitchGreenLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
