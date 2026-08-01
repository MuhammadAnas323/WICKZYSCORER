// lib/ui/scorer/tournaments/view/scorer_tournaments_screen.dart
// Full "My Tournaments" list used by the scorer bottom-nav Tournaments tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class ScorerTournamentsScreen extends ConsumerWidget {
  const ScorerTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scorerDashboardViewModelProvider);
    final tournaments = state.tournaments;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.floodlightGold, Colors.orangeAccent],
                ),
              ),
              child: const Icon(Icons.emoji_events, color: Colors.black, size: 20),
            ),
            const Gap(10),
            Text(
              'My Tournaments',
              style: AppTextStyles.titleMedium(Colors.white)
                  .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.pitchGreenLight, size: 28),
            tooltip: 'Create Tournament',
            onPressed: () => context.push('/scorer/tournaments/create'),
          ),
          const Gap(8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.pitchGreen,
        onRefresh: () async {
          await ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
        },
        child: tournaments.isEmpty
            ? _emptyState(context, ref)
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: tournaments.length,
                itemBuilder: (ctx, i) => _tournamentCard(context, tournaments[i]),
              ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: AppColors.pitchGreen,
          onRefresh: () async {
            await ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 120),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.charcoal400),
                const Gap(16),
                const Text(
                  'No tournaments yet',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Gap(6),
                const Text(
                  'Create your first tournament and start scoring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Gap(24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Create Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => context.push('/scorer/tournaments/create'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tournamentCard(BuildContext context, ScorerTournament t) {
    return InkWell(
      onTap: () => context.push('/scorer/tournaments/${t.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 22)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.pitchGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.format.name.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.pitchGreenLight),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              t.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${t.numTeams} Teams',
              style: const TextStyle(color: AppColors.pitchGreenLight, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const Gap(2),
            Text(
              t.venue,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
