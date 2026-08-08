// lib/ui/scorer/tournaments/view/scorer_tournaments_screen.dart
// Full "My Tournaments" list used by the scorer bottom-nav Tournaments tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/shared_widgets/tournament_card.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';

class ScorerTournamentsScreen extends ConsumerWidget {
  const ScorerTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scorerDashboardViewModelProvider);
    final tournaments = state.tournaments;
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    // A tournament counts as completed when every match linked to it has been
    // completed; otherwise it is still active (has live/upcoming matches, or
    // has no matches scored yet).
    final completed = tournaments.where((t) {
      final tMatches =
          state.matches.where((m) => m.tournamentId == t.id).toList();
      return tMatches.isNotEmpty &&
          tMatches.every((m) => m.status == MatchStatus.completed);
    }).toList();
    final active = tournaments.where((t) => !completed.contains(t)).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              l10n.translate('my_tournaments'),
              style: AppTextStyles.titleMedium(cs.onBackground)
                  .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: const [],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scorer/tournaments/create'),
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        tooltip: l10n.translate('create_tournament'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        color: AppColors.pitchGreen,
        onRefresh: () async {
          await ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
        },
        child: tournaments.isEmpty
            ? _emptyState(context, ref, l10n)
            : ListView(
                padding: const EdgeInsets.only(bottom: 24, top: 4),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (active.isNotEmpty) ...[
                    _sectionHeader(context, cs, 'Active'),
                    ...active.map((t) => TournamentCard(
                          tournament: t,
                          onTap: () =>
                              context.push('/scorer/tournaments/${t.id}'),
                        )),
                  ],
                  if (completed.isNotEmpty) ...[
                    _sectionHeader(
                        context, cs, l10n.translate('completed')),
                    ...completed.map((t) => TournamentCard(
                          tournament: t,
                          onTap: () =>
                              context.push('/scorer/tournaments/${t.id}'),
                        )),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.pitchGreenLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(8),
          Text(title,
              style: AppTextStyles.titleMedium(cs.onSurface)
                  .copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: AppColors.pitchGreen,
          onRefresh: () async {
            await ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.charcoal400),
                    const Gap(16),
                    Text(
                      l10n.translate('no_tournaments'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const Gap(6),
                    Text(
                      l10n.translate('create_first_tournament'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                      label: Text(l10n.translate('create_tournament'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => context.push('/scorer/tournaments/create'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
