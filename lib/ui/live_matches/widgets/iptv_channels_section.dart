import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/data/providers/iptv_provider.dart';
import 'package:sportyapp/ui/live_matches/view/live_video_player_screen.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class IptvChannelsSection extends ConsumerStatefulWidget {
  const IptvChannelsSection({super.key});

  @override
  ConsumerState<IptvChannelsSection> createState() => _IptvChannelsSectionState();
}

class _IptvChannelsSectionState extends ConsumerState<IptvChannelsSection> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(iptvProvider);
    final channelsAsync = ref.watch(iptvChannelsStreamProvider);

    return channelsAsync.when(
      data: (channels) {
        if (channels.isEmpty) return const SizedBox.shrink();
        return _buildSection(cs, channels, state);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSection(ColorScheme cs, List<IptvChannel> allChannels, IptvState state) {
    final filtered = state.filterChannels(allChannels);
    final groups = allChannels
        .map((c) => c.group)
        .where((g) => g != null && g!.isNotEmpty)
        .toSet()
        .map((g) => g!)
        .toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('\u{1F4FA}  IPTV Channels', style: AppTextStyles.titleLarge(cs.onBackground)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${allChannels.length}', style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search IPTV channels...',
              hintStyle: AppTextStyles.bodySmall(cs.onSurfaceVariant.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(iptvProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
            ),
            style: AppTextStyles.bodySmall(cs.onBackground),
            onChanged: (v) => ref.read(iptvProvider.notifier).setSearchQuery(v),
          ),
        ),
        if (groups.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('All', style: TextStyle(fontSize: 11)),
                  selected: state.selectedGroup == null,
                  onSelected: (_) => ref.read(iptvProvider.notifier).setSelectedGroup(null),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(g, style: const TextStyle(fontSize: 11)),
                    selected: state.selectedGroup == g,
                    onSelected: (_) => ref.read(iptvProvider.notifier).setSelectedGroup(g),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )),
              ],
            ),
          ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text('No channels match your search', style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
          )
        else
          ...filtered.map((ch) => _channelTile(cs, ch)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _channelTile(ColorScheme cs, IptvChannel channel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: channel.logo != null && channel.logo!.isNotEmpty
                ? Image.network(channel.logo!, width: 36, height: 36, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _defaultLogo(cs))
                : _defaultLogo(cs),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.channelName, style: AppTextStyles.bodySmall(cs.onBackground).copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (channel.group != null && channel.group!.isNotEmpty)
                  Text(channel.group!, style: AppTextStyles.labelSmall(cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!channel.isAvailable)
            const Icon(Icons.error_outline, color: Colors.orange, size: 18)
          else
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: AppColors.pitchGreenLight, size: 26),
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

  Widget _defaultLogo(ColorScheme cs) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.tv, color: cs.onSurfaceVariant, size: 18),
    );
  }
}
