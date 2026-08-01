import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/section_header.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/ui/spectator/widgets/spectator_match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
                ),
              ),
              child: const Icon(Icons.sports_cricket,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'CRIXORA',
              style: AppTextStyles.titleLarge(cs.onBackground)
                  .copyWith(letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.isLoading
          ? const MatchListSkeleton()
          : state.error != null && state.matches.isEmpty
              ? _ErrorState(onRetry: () =>
                  ref.read(spectatorHomeViewModelProvider.notifier).refresh())
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
                  child: _buildContent(context, ref, state),
                ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, SpectatorHomeState state) {
    final hasContent = state.liveMatches.isNotEmpty ||
        state.upcomingMatches.isNotEmpty ||
        state.completedMatches.isNotEmpty;

    if (!hasContent) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyState(
            emoji: '🏏',
            title: 'No matches yet',
            subtitle:
                'Live, upcoming and completed matches scored in the app will appear here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Tournaments quick access ─────────────────────────────────────
        if (state.tournaments.isNotEmpty) ...[
          SectionHeader(
            title: '🏆  Tournaments',
            onSeeAll: () => context.go('/events'),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: state.tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _TournamentPill(
                name: state.tournaments[i].name,
                onTap: () => context.push('/events/${state.tournaments[i].id}'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Live matches ─────────────────────────────────────────────────
        if (state.liveMatches.isNotEmpty) ...[
          SectionHeader(
            title: '🔴  Live',
            onSeeAll: state.liveMatches.length > 1
                ? () => context.go('/live')
                : null,
          ),
          ...state.liveMatches.map((m) => SpectatorMatchCard(
                match: m,
                teamName: state.teamName,
                teamShort: state.teamShort,
                tournamentName: (id) =>
                    state.tournamentById(id)?.name ?? 'Custom Match',
                onTap: () => context.push('/spectator/match/${m.id}'),
              )),
          const SizedBox(height: 8),
        ],

        // ── Upcoming matches ─────────────────────────────────────────────
        if (state.upcomingMatches.isNotEmpty) ...[
          SectionHeader(title: '📅  Upcoming'),
          ...state.upcomingMatches.map((m) => SpectatorMatchCard(
                match: m,
                teamName: state.teamName,
                teamShort: state.teamShort,
                tournamentName: (id) =>
                    state.tournamentById(id)?.name ?? 'Custom Match',
                onTap: () => context.push('/spectator/match/${m.id}'),
              )),
          const SizedBox(height: 8),
        ],

        // ── Completed matches ────────────────────────────────────────────
        if (state.completedMatches.isNotEmpty) ...[
          SectionHeader(title: '🏁  Completed'),
          ...state.completedMatches.map((m) => SpectatorMatchCard(
                match: m,
                teamName: state.teamName,
                teamShort: state.teamShort,
                tournamentName: (id) =>
                    state.tournamentById(id)?.name ?? 'Custom Match',
                onTap: () => context.push('/spectator/match/${m.id}'),
              )),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TournamentPill extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _TournamentPill({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: cs.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              name,
              style: AppTextStyles.titleSmall(cs.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        emoji: '⚠️',
        title: 'Something went wrong',
        subtitle: 'Unable to load matches.',
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}
