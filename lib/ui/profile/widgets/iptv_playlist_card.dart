import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/data/providers/iptv_provider.dart';
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class IptvPlaylistCard extends ConsumerStatefulWidget {
  const IptvPlaylistCard({super.key});

  @override
  ConsumerState<IptvPlaylistCard> createState() => _IptvPlaylistCardState();
}

class _IptvPlaylistCardState extends ConsumerState<IptvPlaylistCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(iptvProvider);
    final channelsAsync = ref.watch(iptvChannelsStreamProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.live_tv_rounded, color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('\u{1F4FA}  IPTV Playlist Manager',
                          style: AppTextStyles.bodyMedium(cs.onBackground).copyWith(fontWeight: FontWeight.w600)),
                        if (state.settings != null && state.settings!.playlistUrl.isNotEmpty)
                          Text('${state.settings!.channelCount} channels imported',
                            style: AppTextStyles.labelSmall(AppColors.pitchGreenLight))
                        else
                          Text('No playlist loaded',
                            style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.info,
                            side: const BorderSide(color: AppColors.info),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Manage Playlist', style: TextStyle(fontSize: 12)),
                          onPressed: () => context.push('/iptv-management'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  channelsAsync.when(
                    data: (channels) {
                      if (channels.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('No channels imported. Tap "Manage Playlist" to add one.',
                              style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
                          ),
                        );
                      }
                      final displayed = channels.take(5).toList();
                      return Column(
                        children: [
                          ...displayed.map((ch) => _miniChannelTile(cs, ch)),
                          if (channels.length > 5) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => context.push('/iptv-management'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceVariant.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('+ ${channels.length - 5} more channels',
                                    style: AppTextStyles.labelSmall(AppColors.info)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                    error: (_, __) => Center(
                      child: Text('Failed to load channels', style: AppTextStyles.bodySmall(Colors.red)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniChannelTile(ColorScheme cs, IptvChannel channel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: channel.logo != null && channel.logo!.isNotEmpty
                ? Image.network(channel.logo!, width: 28, height: 28, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.tv, color: cs.onSurfaceVariant, size: 20))
                : Icon(Icons.tv, color: cs.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(channel.channelName,
              style: AppTextStyles.bodySmall(cs.onBackground),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (channel.isAvailable)
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: AppColors.pitchGreenLight, size: 22),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LiveVideoPlayerScreen(url: channel.streamUrl, title: channel.channelName),
              )),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
