import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/providers/m3u_provider.dart';
import 'package:sportyapp/data/models/m3u_channel_model.dart';
import 'package:sportyapp/core/utils/m3u_parser.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class M3uChannelsScreen extends ConsumerStatefulWidget {
  final String playlistUrl;
  const M3uChannelsScreen({super.key, required this.playlistUrl});

  @override
  ConsumerState<M3uChannelsScreen> createState() => _M3uChannelsScreenState();
}

class _M3uChannelsScreenState extends ConsumerState<M3uChannelsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(m3uProvider);
    if (!state.hasPlaylist || state.playlist?.sourceUrl != widget.playlistUrl) {
      ref.read(m3uProvider.notifier).loadPlaylist(widget.playlistUrl);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _playChannel(M3uChannel channel) {
    if (!channel.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Channel stream format is not supported'), backgroundColor: Colors.orange),
      );
      return;
    }
    _openPlayer(channel.url, channel.name);
  }

  void _openPlayer(String url, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveVideoPlayerScreen(url: url, title: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(m3uProvider);
    final notifier = ref.read(m3uProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.playlist?.title.isNotEmpty == true
            ? state.playlist!.title
            : 'IPTV Channels'),
        actions: [
          if (state.hasPlaylist)
            IconButton(
              icon: state.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              onPressed: state.isLoading ? null : () => notifier.refresh(),
            ),
          if (state.hasPlaylist)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (group) => notifier.setSelectedGroup(group),
              itemBuilder: (_) {
                final groups = state.playlist?.groups ?? [];
                return [
                  const PopupMenuItem(value: null, child: Text('All Groups')),
                  ...groups.map((g) => PopupMenuItem(value: g, child: Text(g))),
                ];
              },
            ),
        ],
      ),
      body: _buildBody(cs, state, notifier),
    );
  }

  Widget _buildBody(ColorScheme cs, M3uState state, M3uNotifier notifier) {
    if (state.isLoading && !state.hasPlaylist) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && !state.hasPlaylist) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load playlist', style: AppTextStyles.titleLarge(cs.onBackground)),
              const SizedBox(height: 8),
              Text(state.error!, style: AppTextStyles.bodyMedium(cs.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => notifier.loadPlaylist(widget.playlistUrl),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasPlaylist) {
      return const SizedBox.shrink();
    }

    final channels = state.filteredChannels;
    final total = state.playlist!.channels.length;
    final available = state.playlist!.availableChannels;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: cs.surfaceVariant.withOpacity(0.3),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search channels...',
                    hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              notifier.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  style: AppTextStyles.bodyMedium(cs.onBackground),
                  onChanged: notifier.setSearchQuery,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: cs.surfaceVariant.withOpacity(0.15),
          child: Row(
            children: [
              Text('$total channels', style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
              if (state.selectedGroup != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.floodlightGoldLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(state.selectedGroup!, style: const TextStyle(color: AppColors.floodlightGoldLight, fontSize: 11)),
                ),
              ],
              const Spacer(),
              Text('$available playable', style: AppTextStyles.labelSmall(AppColors.pitchGreenLight)),
            ],
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? Center(
                  child: Text('No channels match your search',
                    style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: channels.length,
                  itemBuilder: (_, i) => _channelTile(cs, channels[i]),
                ),
        ),
      ],
    );
  }

  Widget _channelTile(ColorScheme cs, M3uChannel channel) {
    final streamType = M3uParser.isPlayableStream(channel.url) ? 'Playable' : 'Unsupported';

    return Card(
      color: cs.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: channel.logo != null && channel.logo!.isNotEmpty
              ? Image.network(
                  channel.logo!,
                  width: 40, height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _defaultLogo(cs),
                )
              : _defaultLogo(cs),
        ),
        title: Text(channel.name, style: AppTextStyles.bodyMedium(cs.onBackground).copyWith(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            if (channel.group != null && channel.group!.isNotEmpty) ...[
              Text(channel.group!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: channel.isAvailable
                    ? AppColors.pitchGreenLight.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                streamType,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: channel.isAvailable ? AppColors.pitchGreenLight : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        trailing: channel.isAvailable
            ? const Icon(Icons.play_circle_fill, color: AppColors.pitchGreenLight, size: 28)
            : const Icon(Icons.error_outline, color: Colors.orange, size: 20),
        onTap: channel.isAvailable
            ? () => _openPlayer(channel.url, channel.name)
            : null,
      ),
    );
  }

  Widget _defaultLogo(ColorScheme cs) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.tv, color: cs.onSurfaceVariant, size: 22),
    );
  }
}
