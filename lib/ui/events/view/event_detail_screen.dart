import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
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

    // Scheduled / upcoming matches shown in the "Match Schedule" section.
    final upcoming = matches
        .where((m) =>
            m.status == MatchStatus.upcoming ||
            m.status == MatchStatus.scheduled)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final liveMatches = matches.where((m) =>
        m.status == MatchStatus.inProgress ||
        m.status == MatchStatus.live).toList();

    // Stage-wise schedule built by the organizer. The schedule itself is shown
    // on its own screen (TournamentScheduleScreen) via the button below.
    final scheduleStages = state.scheduleForTournament(tournamentId)
        .where((s) => s.fixtures.isNotEmpty)
        .toList();
    final scheduledCount = scheduleStages.fold<int>(
            0, (sum, s) => sum + s.fixtures.length) +
        upcoming.length;
    final hasScheduleData = scheduleStages.isNotEmpty || upcoming.isNotEmpty;

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

            // Match Schedule button → dedicated schedule screen.
            if (hasScheduleData) ...[
              _ScheduleButton(
                scheduledCount: scheduledCount,
                onTap: () => context.push('/events/$tournamentId/schedule'),
                cs: cs,
              ),
              const Gap(16),
            ],

            // Rules, Requirements & Description Buttons
            if ((tournament.description != null && tournament.description!.isNotEmpty) ||
                (tournament.tournamentRules != null && tournament.tournamentRules!.isNotEmpty) ||
                (tournament.tournamentRequirements != null && tournament.tournamentRequirements!.isNotEmpty)) ...[
              if (tournament.description != null && tournament.description!.isNotEmpty) ...[
                _InfoCardButton(
                  title: 'Description',
                  subtitle: 'About this tournament',
                  icon: Icons.description,
                  gradient: LinearGradient(
                    colors: [AppColors.vibrantBlue.withOpacity(0.8), AppColors.vibrantBlue.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Description'),
                        content: SingleChildScrollView(child: Text(tournament.description!)),
                        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                      ),
                    );
                  },
                  cs: cs,
                ),
                const Gap(8),
              ],
              if (tournament.tournamentRules != null && tournament.tournamentRules!.isNotEmpty) ...[
                _InfoCardButton(
                  title: 'Rules',
                  subtitle: 'Tournament rules & guidelines',
                  icon: Icons.gavel,
                  gradient: LinearGradient(
                    colors: [AppColors.vibrantRed.withOpacity(0.8), AppColors.vibrantRed.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Rules'),
                        content: SingleChildScrollView(child: Text(tournament.tournamentRules!)),
                        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                      ),
                    );
                  },
                  cs: cs,
                ),
                const Gap(8),
              ],
              if (tournament.tournamentRequirements != null && tournament.tournamentRequirements!.isNotEmpty) ...[
                _InfoCardButton(
                  title: 'Requirements',
                  subtitle: 'Eligibility & requirements',
                  icon: Icons.assignment,
                  gradient: LinearGradient(
                    colors: [AppColors.vibrantCyan.withOpacity(0.8), AppColors.vibrantCyan.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Requirements'),
                        content: SingleChildScrollView(child: Text(tournament.tournamentRequirements!)),
                        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                      ),
                    );
                  },
                  cs: cs,
                ),
                const Gap(8),
              ],
              const Gap(8),
            ],

            // Live matches section (completed removed as requested)
            if (liveMatches.isNotEmpty) ...[
              _sectionHeader(cs, 'Live Matches'),
              const Gap(8),
              ...liveMatches.map((m) => Container(
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
                            color: AppColors.vibrantRed,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'LIVE',
                            style: AppTextStyles.labelSmall(Colors.white),
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

            // Teams & Squads button
            _InfoCardButton(
              title: 'Teams & Squads',
              subtitle: '${teams.length} team${teams.length == 1 ? '' : 's'} registered',
              icon: Icons.groups_rounded,
              gradient: LinearGradient(
                colors: [
                  AppColors.floodlightGold.withOpacity(0.85),
                  AppColors.floodlightGold.withOpacity(0.55)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _showTeamsSquadsSheet(context, cs, teams, state),
              cs: cs,
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  void _showTeamsSquadsSheet(
    BuildContext context,
    ColorScheme cs,
    List teams,
    dynamic state,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: cs.background,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.floodlightGold.withOpacity(0.85),
                                AppColors.floodlightGold.withOpacity(0.5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.groups_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const Gap(12),
                        Text(
                          'Teams & Squads',
                          style: AppTextStyles.titleLarge(cs.onSurface)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${teams.length} teams',
                          style: AppTextStyles.labelSmall(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: cs.outlineVariant, height: 1),
                  // Teams list
                  Expanded(
                    child: teams.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.group_off_outlined,
                                    size: 56,
                                    color: cs.onSurfaceVariant
                                        .withOpacity(0.3)),
                                const Gap(12),
                                Text('No teams added yet.',
                                    style: AppTextStyles.bodyMedium(
                                        cs.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            itemCount: teams.length,
                            itemBuilder: (_, i) {
                              final team = teams[i];
                              final players = state.playersForTeam(team.id);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.floodlightGold.withOpacity(0.10),
                                      cs.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(AppConstants.radiusMD),
                                  border: Border.all(
                                      color: AppColors.floodlightGold
                                          .withOpacity(0.25)),
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
                                        colors: [
                                          AppColors.floodlightGold,
                                          AppColors.pitchGreen
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      team.shortCode.isNotEmpty
                                          ? team.shortCode
                                              .substring(
                                                  0,
                                                  team.shortCode.length > 3
                                                      ? 3
                                                      : team.shortCode.length)
                                              .toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  title: Text(team.name,
                                      style:
                                          AppTextStyles.titleSmall(cs.onSurface)
                                              .copyWith(
                                                  fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${players.length} players · ${team.ownerName ?? 'No owner'}',
                                    style: AppTextStyles.labelSmall(
                                        cs.onSurfaceVariant),
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  expandedCrossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (players.isEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'No players registered yet.',
                                          style: AppTextStyles.bodySmall(
                                              cs.onSurfaceVariant),
                                        ),
                                      )
                                    else
                                      ...players.map((p) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.pitchGreen
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '${p.jerseyNumber ?? '-'}',
                                                    style:
                                                        AppTextStyles.labelSmall(
                                                            AppColors
                                                                .pitchGreenLight),
                                                  ),
                                                ),
                                                const Gap(10),
                                                Expanded(
                                                  child: Text(p.name,
                                                      style: AppTextStyles
                                                          .bodyMedium(
                                                              cs.onSurface)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: cs.surfaceVariant,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            100),
                                                  ),
                                                  child: Text(
                                                    _roleLabel(p.role),
                                                    style:
                                                        AppTextStyles.labelSmall(
                                                            cs.onSurfaceVariant),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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

class _ScheduleButton extends StatelessWidget {
  final VoidCallback onTap;
  final int scheduledCount;
  final ColorScheme cs;

  const _ScheduleButton({
    required this.onTap,
    required this.scheduledCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.pitchGreen.withOpacity(0.8),
              AppColors.pitchGreen.withOpacity(0.5)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: AppColors.pitchGreen),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month,
                  color: Colors.white, size: 22),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Match Schedule',
                    style: AppTextStyles.titleSmall(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Gap(2),
                  Text(
                    '$scheduledCount scheduled matches',
                    style: AppTextStyles.labelSmall(cs.onSurfaceVariant).copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
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

class _InfoCardButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _InfoCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const Gap(2),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall(cs.onSurfaceVariant).copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
