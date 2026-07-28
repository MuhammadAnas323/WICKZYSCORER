import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/data/providers/iptv_provider.dart';
import 'package:sportyapp/core/utils/iptv_parser.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class IptvManagementScreen extends ConsumerStatefulWidget {
  const IptvManagementScreen({super.key});

  @override
  ConsumerState<IptvManagementScreen> createState() => _IptvManagementScreenState();
}

class _IptvManagementScreenState extends ConsumerState<IptvManagementScreen> {
  final _urlCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _download() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showSnack('Enter a playlist URL', Colors.red);
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showSnack('URL must start with http:// or https://', Colors.red);
      return;
    }
    ref.read(iptvProvider.notifier).downloadPlaylist(url);
  }

  void _refresh() {
    final settings = ref.read(iptvProvider).settings;
    final url = settings?.playlistUrl;
    if (url == null || url.isEmpty) {
      _showSnack('No playlist URL to refresh', Colors.orange);
      return;
    }
    _urlCtrl.text = url;
    ref.read(iptvProvider.notifier).refreshPlaylist(url);
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear IPTV Playlist?'),
        content: const Text('This will remove the playlist URL and all downloaded channels from Firestore and local cache.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(iptvProvider.notifier).clearAll();
              _urlCtrl.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _playChannel(IptvChannel channel) {
    if (!channel.isAvailable) {
      _showSnack('Channel currently unavailable.', Colors.orange);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiveVideoPlayerScreen(url: channel.streamUrl, title: channel.channelName),
    ));
  }

  void _deleteChannel(IptvChannel channel) {
    ref.read(iptvProvider.notifier).deleteChannel(channel.channelId);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(iptvProvider);
    final channelsAsync = ref.watch(iptvChannelsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('IPTV Playlist Manager')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('\u{1F4FA}  IPTV Playlist Manager', style: AppTextStyles.titleLarge(cs.onBackground)),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              hintText: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
              hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
              labelText: 'Playlist URL (.m3u)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: AppTextStyles.bodyMedium(cs.onBackground),
          ),
          const SizedBox(height: 12),
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
                    icon: state.isDownloading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 18),
                    label: Text(state.isDownloading ? 'Downloading...' : 'Download Playlist'),
                    onPressed: state.isDownloading ? null : _download,
                  ),
                ),
              ),
            ],
          ),
          if (state.settings != null && state.settings!.playlistUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Playlist'),
                    onPressed: state.isDownloading ? null : _refresh,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  onPressed: state.isDownloading ? null : _clear,
                ),
              ],
            ),
          ],
          if (state.isDownloading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.downloadPhase, style: TextStyle(color: AppColors.info, fontSize: 14))),
                ],
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],
          if (state.totalChannels != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreenLight.withOpacity(0.15), cs.surface],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.pitchGreenLight.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.pitchGreenLight, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playlist Imported Successfully', style: AppTextStyles.titleSmall(AppColors.pitchGreenLight)),
                      const SizedBox(height: 4),
                      Text(
                        'Imported ${state.totalChannels} Channels (${state.playableChannels} playable)',
                        style: AppTextStyles.bodySmall(cs.onBackground),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('\u{1F4E1}  Imported Channels', style: AppTextStyles.titleLarge(cs.onBackground)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by channel name, country, or category...',
              hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(iptvProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
            ),
            style: AppTextStyles.bodyMedium(cs.onBackground),
            onChanged: (v) => ref.read(iptvProvider.notifier).setSearchQuery(v),
          ),
          const SizedBox(height: 12),
          channelsAsync.when(
            data: (channels) => _buildChannelList(cs, channels, state),
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load channels', style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelList(ColorScheme cs, List<IptvChannel> allChannels, IptvState state) {
    final filtered = state.filterChannels(allChannels);

    if (allChannels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.tv_off, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text('No channels imported yet', style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Download a playlist to get started', style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Text('${filtered.length} of $allChannels.length channels', style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
            const Spacer(),
            if (state.selectedGroup != null)
              Chip(
                label: Text(state.selectedGroup!, style: const TextStyle(fontSize: 11)),
                onDeleted: () => ref.read(iptvProvider.notifier).setSelectedGroup(null),
                visualDensity: VisualDensity.compact,
              ),
            PopupMenuButton<String?>(
              icon: Icon(Icons.filter_list, color: cs.onSurfaceVariant),
              onSelected: (g) => ref.read(iptvProvider.notifier).setSelectedGroup(g),
              itemBuilder: (_) {
                final groups = allChannels
                    .map((c) => c.group)
                    .where((g) => g != null && g!.isNotEmpty)
                    .toSet()
                    .map((g) => g!)
                    .toList()..sort();
                return [
                  const PopupMenuItem(value: null, child: Text('All Groups')),
                  ...groups.map((g) => PopupMenuItem(value: g, child: Text(g))),
                ];
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No channels match your search', style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
          )
        else
          ...filtered.map((channel) => _channelTile(cs, channel)),
      ],
    );
  }

  Widget _channelTile(ColorScheme cs, IptvChannel channel) {
    return Card(
      color: cs.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outline.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: channel.logo != null && channel.logo!.isNotEmpty
                  ? Image.network(channel.logo!, width: 44, height: 44, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _defaultLogo(cs))
                  : _defaultLogo(cs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.channelName, style: AppTextStyles.bodyMedium(cs.onBackground).copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (channel.group != null && channel.group!.isNotEmpty) ...[
                        Text(channel.group!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(width: 8),
                      ],
                      if (channel.country != null && channel.country!.isNotEmpty)
                        Text(channel.country!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            if (!channel.isAvailable)
              const Icon(Icons.error_outline, color: Colors.orange, size: 20)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill, color: AppColors.pitchGreenLight, size: 28),
                    onPressed: () => _playChannel(channel),
                    tooltip: 'Play',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7), size: 20),
                    onPressed: () => _deleteChannel(channel),
                    tooltip: 'Delete',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultLogo(ColorScheme cs) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.tv, color: cs.onSurfaceVariant, size: 24),
    );
  }
}
