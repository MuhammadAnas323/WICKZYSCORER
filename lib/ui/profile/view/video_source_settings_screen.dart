import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:sportyapp/data/models/video_source_model.dart';
import 'package:sportyapp/data/providers/video_source_provider.dart';
import 'package:sportyapp/core/utils/stream_url_validator.dart';
import 'package:sportyapp/core/utils/m3u_parser.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class VideoSourceSettingsScreen extends ConsumerStatefulWidget {
  const VideoSourceSettingsScreen({super.key});

  @override
  ConsumerState<VideoSourceSettingsScreen> createState() => _VideoSourceSettingsScreenState();
}

class _VideoSourceSettingsScreenState extends ConsumerState<VideoSourceSettingsScreen> {
  final _urlCtrl = TextEditingController();
  VideoPlayerController? _playerController;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(videoSourceProvider).valueOrNull;
    if (settings != null) {
      _urlCtrl.text = settings.userUrl;
      if (settings.resolvedStreamUrl != null && settings.resolvedStreamUrl!.isNotEmpty) {
        _initPlayer(settings.resolvedStreamUrl!);
      }
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer(String url) async {
    await _playerController?.dispose();
    _playerController = null;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _playerController = controller;
    try {
      await controller.initialize();
      controller.play();
      if (mounted) setState(() => _playerReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Player error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final notifier = ref.read(videoSourceProvider.notifier);
    final current = ref.read(videoSourceProvider).valueOrNull ?? const VideoSourceSettings();
    await notifier.saveSettings(current.copyWith(userUrl: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL saved')),
      );
    }
  }

  Future<void> _resolveStream() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a URL first'), backgroundColor: Colors.red),
      );
      return;
    }

    if (M3uParser.isM3uPlaylist(url)) {
      context.push('/m3u-channels?url=${Uri.encodeComponent(url)}');
      return;
    }

    final validation = StreamUrlValidator.validate(url);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.error!), backgroundColor: Colors.red),
      );
      return;
    }

    final resultNotifier = ref.read(videoSourceResultProvider.notifier);
    final settingsNotifier = ref.read(videoSourceProvider.notifier);
    final currentSettings = ref.read(videoSourceProvider).valueOrNull ?? const VideoSourceSettings();

    await resultNotifier.resolve(url);

    final state = ref.read(videoSourceResultProvider);
    if (state.result?.success == true && state.result!.streams.isNotEmpty) {
      final streamUrl = state.result!.streams.first.url;
      final format = state.result!.streams.first.format;
      await _initPlayer(streamUrl);
      await settingsNotifier.saveSettings(currentSettings.copyWith(
        userUrl: url,
        resolvedStreamUrl: streamUrl,
        resolvedFormat: format,
        lastResolvedAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${state.result!.streams.length} stream(s) — playing first')),
        );
      }
    }
  }

  void _retry() {
    ref.read(videoSourceResultProvider.notifier).clearResult();
    _resolveStream();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(videoSourceProvider).valueOrNull;
    final resultState = ref.watch(videoSourceResultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Video Source Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Test video source resolver', style: AppTextStyles.titleMedium(cs.onBackground)),
          const SizedBox(height: 4),
          Text(
            'Paste a website URL to search for publicly accessible video streams, '
            'or paste an .m3u IPTV playlist URL to browse channels. '
            'Supported formats: .m3u8 (HLS), .mpd (DASH), .mp4, and .m3u playlists.',
            style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              hintText: 'https://example.com/live-stream',
              hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: AppTextStyles.bodyMedium(cs.onBackground),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pitchGreenLight,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save URL'),
                    onPressed: _saveUrl,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: resultState.isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.videocam_outlined, size: 18),
                    label: Text(resultState.isLoading ? 'Searching...' : 'Test Stream'),
                    onPressed: resultState.isLoading ? null : _resolveStream,
                  ),
                ),
              ),
            ],
          ),
          if (settings?.resolvedStreamUrl != null && settings!.resolvedStreamUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pitchGreenLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last resolved stream', style: AppTextStyles.labelSmall(AppColors.pitchGreenLight)),
                  const SizedBox(height: 4),
                  Text(settings.resolvedStreamUrl!, style: AppTextStyles.bodySmall(cs.onBackground), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (settings.resolvedFormat != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pitchGreenLight.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(settings.resolvedFormat!.toUpperCase(), style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (resultState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resultState.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            onPressed: _retry,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (resultState.result != null && !resultState.result!.success) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resultState.result!.message, style: const TextStyle(color: Colors.orange, fontSize: 13)),
                        if (resultState.result!.detail != null) ...[
                          const SizedBox(height: 4),
                          Text(resultState.result!.detail!, style: const TextStyle(color: Colors.orange, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (resultState.result?.streams != null && resultState.result!.streams.length > 1) ...[
            const SizedBox(height: 12),
            Text('Available streams:', style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            ...resultState.result!.streams.sublist(1).map((stream) => Card(
              color: cs.surface,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: cs.outline.withOpacity(0.1)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.floodlightGoldLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text(stream.format.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.floodlightGoldLight))),
                ),
                title: Text(stream.url, style: AppTextStyles.bodySmall(cs.onBackground), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _initPlayer(stream.url),
              ),
            )),
          ],
          if (_playerReady && _playerController != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: _playerController!.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_playerController!),
                    _PlayPauseOverlay(controller: _playerController!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            VideoProgressIndicator(
              _playerController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: AppColors.pitchGreenLight,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ],
          if (resultState.log.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Debug Log', style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('console', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
                      GestureDetector(
                        onTap: () => ref.read(videoSourceResultProvider.notifier).clearResult(),
                        child: const Text('clear', style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...resultState.log.map((line) => Text(
                    line,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                  )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _PlayPauseOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: controller.value.isPlaying
          ? const SizedBox.shrink()
          : Center(
              child: Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),
    );
  }
}
