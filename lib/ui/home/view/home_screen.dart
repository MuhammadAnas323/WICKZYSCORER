import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/core/extensions/datetime_extensions.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/providers/live_streams_provider.dart';
import 'package:sportyapp/data/providers/cricket_api_provider.dart';
import 'package:sportyapp/data/models/cricket_feed_item.dart';
import 'package:sportyapp/ui/home/viewmodel/home_viewmodel.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/section_header.dart';
import 'package:sportyapp/shared_widgets/match_card.dart';
import 'package:sportyapp/shared_widgets/ball_strip.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          _buildAppBar(context, state, ref),
        ],
        body: RefreshIndicator(
          color: cs.primary,
          onRefresh: () async {
            await Future.wait([
              ref.read(homeViewModelProvider.notifier).refresh(),
              ref.read(cricketApiProvider.notifier).refreshFeeds(),
            ]);
          },
          child: state.isLoading
              ? _buildSkeleton()
              : _buildContent(context, state, ref),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, HomeState state, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: cs.surface,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.pitchGreen, AppColors.pitchGreenDark]),
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'SPORTYAPP',
              style: AppTextStyles.titleLarge(cs.onBackground)
                  .copyWith(letterSpacing: 0.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.api_rounded, color: AppColors.pitchGreenLight),
          onPressed: () => context.push('/cricket-api-settings'),
          tooltip: 'Cricket API Settings',
        ),
        IconButton(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          onPressed: () => context.push('/admin'),
          tooltip: 'Admin',
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.push('/search'),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded),
              onPressed: () => context.push('/notifications'),
            ),
            Positioned(
              top: 10, right: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.liveRed, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        MatchCardSkeleton(),
        SizedBox(height: 8),
        MatchCardSkeleton(),
        MatchCardSkeleton(),
        MatchCardSkeleton(),
      ],
    );
  }

  Widget _buildContent(BuildContext context, HomeState state, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final liveStreamsAsync = ref.watch(liveStreamsProvider);

    final hasContent = state.liveMatches.isNotEmpty ||
        state.upcomingMatches.isNotEmpty ||
        state.tournaments.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Live Users Section (real-time from Firestore, no refresh needed) ──
        liveStreamsAsync.when(
          data: (streams) {
            if (streams.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(8),
                SectionHeader(title: '🔴  Live Now'),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: streams.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _LiveUserCard(
                      stream: streams[i],
                      onTap: () => context.push('/live-viewer/${streams[i].id}'),
                    ),
                  ),
                ),
                const Gap(8),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        if (!hasContent)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: EmptyState(
              emoji: '🏏',
              title: 'No matches available',
              subtitle: 'Live matches and upcoming fixtures will appear here.',
            ),
          ),

        // Featured live match (glassmorphism hero)
        if (state.liveMatches.isNotEmpty) ...[
          _FeaturedMatchCard(match: state.liveMatches.first),
          const Gap(8),
        ],

        // Live Now section (all official live matches except the featured one)
        if (state.liveMatches.length > 1) ...[
          SectionHeader(
            title: '📺  Matches Live',
            onSeeAll: () => context.go('/live'),
          ),
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: state.liveMatches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 280,
                child: MatchCard(
                  match: state.liveMatches[i],
                  onTap: () => context.push('/match/${state.liveMatches[i].id}'),
                ),
              ),
            ),
          ),
          const Gap(16),
        ],

        // Matches section (formerly Upcoming)
        if (state.upcomingMatches.isNotEmpty) ...[
          SectionHeader(title: '📊  Matches', onSeeAll: () => context.push('/matches')),
          SizedBox(
            height: 200,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: state.upcomingMatches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final m = state.upcomingMatches[i];
                return SizedBox(
                  width: 280,
                  child: _UpcomingMatchCard(match: m,
                    onTap: () => context.push('/match/${m.id}')),
                );
              },
            ),
          ),
          const Gap(16),
        ],

        // Tournaments
        if (state.tournaments.isNotEmpty) ...[
          SectionHeader(title: '🏆  Tournaments',
            onSeeAll: () => context.push('/tournaments')),
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: state.tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _TournamentChip(
                tournament: state.tournaments[i],
                onTap: () => context.push('/tournaments/${state.tournaments[i].id}'),
              ),
            ),
          ),
          const Gap(16),
        ],

        // ── Multi-API Connected Feeds & Channels ──────────────────────
        _buildMultiApiFeedsSection(context, ref),
      ],
    );
  }

  Widget _buildMultiApiFeedsSection(BuildContext context, WidgetRef ref) {
    final apiState = ref.watch(cricketApiProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '🌐  Connected Channels',
          onSeeAll: () => context.push('/cricket-api-settings'),
        ),
        if (apiState.isLoading && apiState.feedItems.isEmpty)
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Fetching connected channels...',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          )
        else if (apiState.errorMessage != null && apiState.feedItems.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(apiState.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => context.push('/cricket-api-settings'),
                  child: const Text('APIs'),
                ),
              ],
            ),
          )
        else if (apiState.feedItems.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.tv_rounded, color: AppColors.pitchGreenLight, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No Connected Channels',
                          style: AppTextStyles.titleSmall(cs.onBackground)),
                      const Text(
                        'Connect channel APIs or enable endpoints in settings.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.push('/cricket-api-settings'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Settings'),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: apiState.feedItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final feed = apiState.feedItems[i];
                return _ApiFeedCard(item: feed);
              },
            ),
          ),
        const Gap(16),
      ],
    );
  }
}

class _ApiFeedCard extends StatelessWidget {
  final CricketFeedItem item;
  const _ApiFeedCard({required this.item});

  void _openChannelPlayer(BuildContext context) {
    final streamUrl = item.streamUrl;
    if (streamUrl != null && streamUrl.trim().isNotEmpty) {
      final encodedUrl = Uri.encodeComponent(streamUrl.trim());
      final encodedTitle = Uri.encodeComponent(item.title.trim());
      context.push(
        '/admin-video?url=$encodedUrl&title=$encodedTitle',
        extra: {'url': streamUrl.trim(), 'title': item.title.trim()},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stream URL configured for this channel card'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isLive = item.status == 'LIVE';
    final isChannel = item.status == 'CHANNEL';
    final hasStream = item.streamUrl != null && item.streamUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () => _openChannelPlayer(context),
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(
            color: isLive
                ? AppColors.liveRed.withOpacity(0.4)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // API Source Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.pitchGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.api_rounded, size: 10, color: AppColors.pitchGreenLight),
                      const SizedBox(width: 4),
                      Text(
                        item.apiSourceName,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pitchGreenLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.liveRed
                        : isChannel
                            ? Colors.blue.withOpacity(0.2)
                            : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isLive
                          ? Colors.white
                          : isChannel
                              ? Colors.blue
                              : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.title,
              style: AppTextStyles.titleSmall(cs.onBackground)
                  .copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.score != null && item.score!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.score!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.pitchGreenLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.format != null)
                  Text(
                    item.format!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                InkWell(
                  onTap: () => _openChannelPlayer(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasStream ? Icons.play_circle_fill_rounded : Icons.info_outline_rounded,
                        size: 16,
                        color: hasStream ? AppColors.pitchGreenLight : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasStream ? 'Watch Channel' : 'No Stream',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasStream ? AppColors.pitchGreenLight : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live User Card ────────────────────────────────────────────────────────────
/// Horizontal card showing a live broadcaster. Appears in the home screen's
/// real-time "Live Now" section powered by [liveStreamsProvider].

class _LiveUserCard extends StatelessWidget {
  final StreamModel stream;
  final VoidCallback onTap;
  const _LiveUserCard({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with LIVE ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Glowing red ring
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [AppColors.liveRed, Colors.transparent],
                      stops: [0.75, 1.0],
                    ),
                    border: Border.all(
                      color: AppColors.liveRed,
                      width: 2.5,
                    ),
                  ),
                ),
                // Avatar
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(stream.broadcasterAvatar),
                ),
                // LIVE badge at bottom of avatar
                Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.liveRed,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Broadcaster name
            Text(
              stream.broadcasterName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Viewer count
            Text(
              '${stream.viewerCount} watching',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphism featured live match hero card.
class _FeaturedMatchCard extends ConsumerWidget {
  final MatchModel match;
  const _FeaturedMatchCard({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final liveData = homeState.liveMatchData[match.id];
    final inn = match.currentInnings;
    return GestureDetector(
      onTap: () => context.push('/match/${match.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A7A3E), Color(0xFF0D2818)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.pitchGreen.withOpacity(0.3),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.floodlightGold.withOpacity(0.08),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    border: Border.all(color: AppColors.glassBorder, width: 1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LiveBadge(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(match.seriesName,
                          style: AppTextStyles.labelMedium(Colors.white70),
                          overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          match.format == MatchFormat.t20 ? 'T20' :
                          match.format == MatchFormat.odi ? 'ODI' : 'TEST',
                          style: AppTextStyles.labelSmall(Colors.white)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${match.teamA.flagEmoji} ${match.teamA.shortName}',
                              style: AppTextStyles.titleLarge(Colors.white)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                liveData != null
                                    ? '${liveData.runs}/${liveData.wickets}'
                                    : match.teamAScore,
                                style: AppTextStyles.score(Colors.white)
                                    .copyWith(fontSize: 28)),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('vs', style: AppTextStyles.bodyMedium(Colors.white54)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${match.teamB.shortName} ${match.teamB.flagEmoji}',
                              style: AppTextStyles.titleLarge(Colors.white)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                liveData != null
                                    ? '${liveData.runs}/${liveData.wickets}'
                                    : match.teamBScore,
                                style: AppTextStyles.score(Colors.white)
                                    .copyWith(fontSize: 28),
                                textAlign: TextAlign.right),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          liveData != null
                            ? 'RR: ${liveData.currentRunRate.toStringAsFixed(2)} | Ov: ${liveData.overs.toStringAsFixed(1)}'
                            : match.requiredRuns != null
                              ? '${match.teamB.shortName} need ${match.requiredRuns} off ${match.remainingBalls} balls'
                              : match.venue,
                          style: AppTextStyles.bodySmall(Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (liveData != null && liveData.lastBall.isNotEmpty)
                        BallStrip(balls: [liveData.lastBall])
                      else if (inn != null && inn.lastSixBalls.isNotEmpty)
                        BallStrip(balls: inn.lastSixBalls),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upcoming match compact card with countdown.
class _UpcomingMatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onTap;
  const _UpcomingMatchCard({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countdown = match.scheduledAt.countdownFrom(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(match.format.name.toUpperCase(),
                    style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.floodlightGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('⏰ $countdown',
                    style: AppTextStyles.labelSmall(AppColors.floodlightGold)),
                ),
              ],
            ),
            const Spacer(),
            Text('${match.teamA.flagEmoji} ${match.teamA.shortName}',
              style: AppTextStyles.titleMedium(cs.onBackground)),
            const SizedBox(height: 2),
            Text('vs ${match.teamB.flagEmoji} ${match.teamB.shortName}',
              style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
            const Spacer(),
            Text(match.venue, style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Tournament chip card.
class _TournamentChip extends StatelessWidget {
  final TournamentModel tournament;
  final VoidCallback onTap;
  const _TournamentChip({required this.tournament, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🏆', style: const TextStyle(fontSize: 24)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tournament.status == 'live'
                        ? AppColors.liveRed
                        : tournament.status == 'upcoming'
                            ? AppColors.floodlightGold.withOpacity(0.2)
                            : cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    tournament.status.toUpperCase(),
                    style: AppTextStyles.labelSmall(
                      tournament.status == 'live' ? Colors.white :
                      tournament.status == 'upcoming' ? AppColors.floodlightGold :
                      cs.onSurfaceVariant)),
                ),
              ],
            ),
            const Spacer(),
            Text(tournament.name,
              style: AppTextStyles.titleSmall(cs.onBackground),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${tournament.completedMatches}/${tournament.totalMatches} matches',
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}