import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:sportyapp/core/utils/stream_url_validator.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class TestVideoPage extends StatefulWidget {
  const TestVideoPage({super.key});

  @override
  State<TestVideoPage> createState() => _TestVideoPageState();
}

class _TestVideoPageState extends State<TestVideoPage> {
  final _urlCtrl = TextEditingController();
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _testing = false;
  StreamFormat _detectedFormat = StreamFormat.unknown;
  String? _statusMessage;
  bool? _statusOk;
  String _log = '';

  @override
  void dispose() {
    _urlCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _logMsg(String msg) {
    _log += '$msg\n';
  }

  Future<void> _testHttp() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _testing = true;
      _statusMessage = null;
      _statusOk = null;
      _log = '';
    });

    _logMsg('Testing HTTP HEAD: $url');
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
      _logMsg('HTTP status: ${response.statusCode}');
      _logMsg('Headers: ${response.headers}');
      setState(() {
        _statusOk = response.statusCode == 200 || response.statusCode == 206;
        _statusMessage = _statusOk! ? 'HTTP ${response.statusCode} OK' : 'HTTP ${response.statusCode}';
      });
    } catch (e) {
      _logMsg('HTTP test failed: $e');
      setState(() {
        _statusOk = false;
        _statusMessage = 'Network error';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _play() async {
    final url = _urlCtrl.text.trim();
    final validation = StreamUrlValidator.validate(url);
    if (!validation.isValid) {
      setState(() {
        _statusMessage = validation.error;
        _statusOk = false;
      });
      return;
    }

    _detectedFormat = StreamUrlValidator.detectFormat(url);
    _logMsg('Detected: ${StreamUrlValidator.formatLabel(_detectedFormat)}');

    await _controller?.dispose();
    _controller = null;
    setState(() {
      _initialized = false;
      _statusMessage = null;
      _statusOk = null;
    });

    try {
      _logMsg('Initializing player...');
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize().timeout(const Duration(seconds: 30));
      _logMsg('Player initialized.');
      _controller!.play();
      if (mounted) {
        setState(() {
          _initialized = true;
          _isPlaying = true;
          _statusMessage = 'Playback started';
          _statusOk = true;
        });
      }
    } on TimeoutException {
      _logMsg('TimeoutException');
      _setError('Stream unavailable — connection timed out');
    } on SocketException catch (e) {
      _logMsg('SocketException: ${e.message}');
      _setError('Network error — could not reach stream source');
    } on HttpException catch (e) {
      _logMsg('HttpException: ${e.message}');
      _setError('Stream unavailable — HTTP error');
    } on FormatException catch (e) {
      _logMsg('FormatException: ${e.message}');
      _setError('Invalid stream URL');
    } catch (e) {
      _logMsg('Exception: $e');
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

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _statusMessage = msg;
        _statusOk = false;
      });
    }
  }

  void _loadSample(String url) {
    _urlCtrl.text = url;
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Test Video Streams')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // URL input
          Text('Enter a video URL to test:', style: AppTextStyles.titleMedium(cs.onBackground)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/stream.m3u8',
                    hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  style: AppTextStyles.bodyMedium(cs.onBackground),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _testing ? Colors.grey : cs.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _testing ? null : _testHttp,
                  child: _testing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Test HTTP'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreenLight,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _play,
                  child: const Text('Play'),
                ),
              ),
            ],
          ),

          // Status
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_statusOk ?? false) ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_statusOk ?? false) ? Colors.green : Colors.red,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_statusOk ?? false) ? Icons.check_circle : Icons.error,
                    color: (_statusOk ?? false) ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: (_statusOk ?? false) ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Format badge
          if (_detectedFormat != StreamFormat.unknown) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pitchGreenLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.4)),
                  ),
                  child: Text(
                    StreamUrlValidator.formatLabel(_detectedFormat),
                    style: const TextStyle(
                      color: AppColors.pitchGreenLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Video player
          if (_initialized) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller!),
                    if (!_isPlaying)
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            _controller!.play();
                            setState(() => _isPlaying = true);
                          },
                          child: Container(
                            width: 56, height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColors.pitchGreenLight,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text('Sample streams:', style: AppTextStyles.titleMedium(cs.onBackground)),
          const SizedBox(height: 8),
          ...StreamUrlValidator.sampleStreams.map((sample) => Card(
            color: cs.surface,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: cs.outline.withOpacity(0.15)),
            ),
            child: ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.pitchGreenLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    sample['type']!,
                    style: const TextStyle(
                      color: AppColors.pitchGreenLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              title: Text(sample['name']!, style: AppTextStyles.bodyMedium(cs.onBackground)),
              subtitle: Text(sample['url']!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.play_circle_fill, color: AppColors.pitchGreenLight),
              onTap: () => _loadSample(sample['url']!),
            ),
          )),

          // Debug log
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Debug Log:', style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                _log,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
