import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/providers/live_streams_provider.dart';
import 'package:sportyapp/data/providers/admin_settings_provider.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/ui/live_matches/widgets/iptv_channels_section.dart';

class LiveMatchesScreen extends ConsumerWidget {
  const LiveMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamsAsync = ref.watch(liveStreamsProvider);
    final settingsAsync = ref.watch(adminSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Live', style: AppTextStyles.headlineSmall(cs.onBackground)),
            const SizedBox(width: 8),
            const LiveBadge(),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(liveStreamsProvider);
        },
        child: streamsAsync.when(
          data: (streams) {
            final settings = settingsAsync.valueOrNull;
            final hasVideoSource = settings != null && settings.videoUrl.isNotEmpty;

            if (streams.isEmpty && !hasVideoSource) {
              return const Center(
                child: EmptyState(
                  emoji: '\u{1F534}',
                  title: 'No live matches available',
                  subtitle: 'There are no active streams right now. Start one and others will see it instantly!',
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (hasVideoSource) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('\u{1F4FA}  Video Source',
                      style: AppTextStyles.titleLarge(cs.onBackground)),
                  ),
                  _VideoSourceCard(
                    matchName: settings!.videoMatchName.isNotEmpty ? settings.videoMatchName : 'Live Match',
                    videoUrl: settings.videoUrl,
                    onTap: () {
                      final streamUrl = settings.videoUrl.trim();
                      final name = settings.videoMatchName.isNotEmpty ? settings.videoMatchName : 'Live Match';
                      if (streamUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No video URL configured. Please set one in Admin Settings.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      context.push(
                        '/admin-video?url=${Uri.encodeComponent(streamUrl)}&title=${Uri.encodeComponent(name)}',
                        extra: {'url': streamUrl, 'title': name},
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (streams.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('\u{1F534}  Live Now',
                      style: AppTextStyles.titleLarge(cs.onBackground)),
                  ),
                  ...streams.map((stream) => _StreamCard(
                    stream: stream,
                    onTap: () => context.push('/live-viewer/${stream.id}'),
                  )),
                ],
                const IptvChannelsSection(),
              ],
            );
          },
          loading: () => const MatchListSkeleton(),
          error: (_, __) => const Center(
            child: EmptyState(
              emoji: '\u{1F6AB}',
              title: 'No live matches available',
              subtitle: 'Unable to fetch live streams. Pull down to retry.',
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final StreamModel stream;
  final VoidCallback onTap;

  const _StreamCard({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(stream.thumbnailUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: cs.surfaceVariant, child: const Icon(Icons.videocam_rounded))),
                    if (stream.status == StreamStatus.live)
                      const Positioned(top: 6, left: 6, child: LiveBadge()),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text('${stream.viewerCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(stream.title, style: AppTextStyles.titleSmall(cs.onBackground), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(radius: 10, backgroundImage: NetworkImage(stream.broadcasterAvatar)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(stream.broadcasterName, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (stream.matchTitle != null && stream.matchTitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(stream.matchTitle!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoSourceCard extends StatelessWidget {
  final String matchName;
  final String videoUrl;
  final VoidCallback onTap;

  const _VideoSourceCard({
    required this.matchName,
    required this.videoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.pitchGreenLight.withOpacity(0.15), cs.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white24, size: 32)),
                    const Positioned(top: 6, left: 6, child: LiveBadge()),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(matchName, style: AppTextStyles.titleSmall(cs.onBackground), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.link, size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('Direct video source', style: AppTextStyles.labelSmall(AppColors.pitchGreenLight), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
