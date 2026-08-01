import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';

class EventDetailScreen extends ConsumerWidget {
  final String tournamentId;
  const EventDetailScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    final tournament = state.tournamentById(tournamentId);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const MatchListSkeleton(),
      );
    }

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tournament not found')),
      );
    }

    final teams = state.teamsForTournament(tournamentId);
    final matches = state.matchesForTournament(tournamentId);
    final completed = matches.where((m) => m.status.name == 'completed').length;
    final live = matches.where((m) => m.status.name == 'inProgress' || m.status.name == 'live').length;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text(tournament.name,
            style: AppTextStyles.headlineSmall(cs.onSurface),
            overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overview banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.heroCardGradient,
                borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: AppColors.floodlightGold, size: 28),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          tournament.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white54, size: 16),
                      const Gap(4),
                      Expanded(
                        child: Text(tournament.venue,
                            style:
                                const TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                    ],
                  ),
                  const Gap(6),
                  Text(
                    '${tournament.startDate.day}/${tournament.startDate.month} — '
                    '${tournament.endDate.day}/${tournament.endDate.month}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Stats row
            Row(
              children: [
                _statTile(cs, '🏑', '${teams.length}', 'Teams'),
                _statTile(cs, '🏏', '${matches.length}', 'Matches'),
                _statTile(cs, '🔴', '$live', 'Live'),
                _statTile(cs, '🏁', '$completed', 'Done'),
              ],
            ),
            const Gap(16),

            // Matches section
            if (matches.isNotEmpty) ...[
              _sectionHeader(cs, 'Matches'),
              const Gap(8),
              ...matches.map((m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: m.status.name == 'inProgress' ||
                                    m.status.name == 'live'
                                ? AppColors.liveRed
                                : m.status.name == 'completed'
                                    ? AppColors.success.withOpacity(0.2)
                                    : cs.surfaceVariant,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            m.status.name == 'inProgress'
                                ? 'LIVE'
                                : m.status.name.toUpperCase(),
                            style: AppTextStyles.labelSmall(
                              m.status.name == 'inProgress' ||
                                      m.status.name == 'live'
                                  ? Colors.white
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            '${state.teamShort(m.team1Id)} vs ${state.teamShort(m.team2Id)}',
                            style: AppTextStyles.titleSmall(cs.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          m.resultSummary ?? m.venue,
                          style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  )),
              const Gap(16),
            ],

            // Teams + squads section
            _sectionHeader(cs, 'Squads (${teams.length})'),
            const Gap(8),
            if (teams.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Text('No teams added yet.',
                    style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
              )
            else
              ...teams.map((team) => _TeamSquadCard(
                    team: team,
                    players: state.playersForTeam(team.id),
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    cs: cs,
                  )),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
      ColorScheme cs, String emoji, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value,
                style: AppTextStyles.titleLarge(cs.onSurface)
                    .copyWith(fontWeight: FontWeight.w700)),
            Text(label,
                style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.pitchGreenLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Text(title, style: AppTextStyles.titleLarge(cs.onSurface)),
      ],
    );
  }
}

class _TeamSquadCard extends StatelessWidget {
  final ScorerTeam team;
  final List<ScorerPlayer> players;
  final bool isDark;
  final ColorScheme cs;

  const _TeamSquadCard({
    required this.team,
    required this.players,
    required this.isDark,
    required this.cs,
  });

  String _roleLabel(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return 'BAT';
      case PlayerRole.bowler:
        return 'BOWL';
      case PlayerRole.allRounder:
        return 'AR';
      case PlayerRole.wicketKeeper:
        return 'WK';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.pitchGreen, AppColors.pitchGreenDark],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            team.shortCode.isNotEmpty
                ? team.shortCode.substring(
                        0, team.shortCode.length > 3 ? 3 : team.shortCode.length)
                    .toUpperCase()
                : 'T',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(team.name,
            style: AppTextStyles.titleSmall(cs.onSurface)
                .copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('${players.length} squad players • ${team.ownerName ?? 'No owner'}',
            style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('No players registered yet.',
                  style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
            )
          else
            ...players.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.pitchGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${p.jerseyNumber ?? '-'}',
                          style: AppTextStyles.labelSmall(
                              AppColors.pitchGreenLight),
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(p.name,
                            style: AppTextStyles.bodyMedium(cs.onSurface)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(_roleLabel(p.role),
                            style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
