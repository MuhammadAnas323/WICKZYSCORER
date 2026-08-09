import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
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
            // Hero card: overview + stats + prizes in one, with its own
            // unique gradient.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: AppColors.floodlightGold, size: 26),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournament.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(3),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white70, size: 13),
                                const Gap(4),
                                Expanded(
                                  child: Text(
                                    tournament.venue,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      _heroStatTile(
                          emoji: '🏑', value: '${teams.length}', label: 'Teams'),
                      _heroStatTile(
                          emoji: '🏏',
                          value: '${matches.length}',
                          label: 'Matches'),
                      _heroStatTile(
                          emoji: '🔴', value: '$live', label: 'Live'),
                      _heroStatTile(
                          emoji: '🏁', value: '$completed', label: 'Done'),
                    ],
                  ),
                  const Gap(14),
                  const Divider(color: Colors.white24, height: 1),
                  const Gap(12),
                  Row(
                    children: [
                      _heroPrizeTile(
                        icon: Icons.payments_outlined,
                        label: 'Entry Fee',
                        value: tournament.entryFee != null
                            ? '\$ ${tournament.entryFee!.toStringAsFixed(0)}'
                            : 'Free',
                        color: Colors.blueAccent,
                      ),
                      const Gap(8),
                      _heroPrizeTile(
                        icon: Icons.emoji_events_rounded,
                        label: 'Winner',
                        value: tournament.winnerPrize != null
                            ? '\$ ${tournament.winnerPrize!.toStringAsFixed(0)}'
                            : 'TBD',
                        color: AppColors.floodlightGoldLight,
                      ),
                      const Gap(8),
                      _heroPrizeTile(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Runner-Up',
                        value: tournament.runnerUpPrize != null
                            ? '\$ ${tournament.runnerUpPrize!.toStringAsFixed(0)}'
                            : 'TBD',
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Match Schedule button (read-only view of stages & fixtures)
            _actionCard(
              context,
              icon: Icons.calendar_month,
              title: 'Match Schedule',
              subtitle: 'Stages, fixtures & upcoming matches',
              gradient: LinearGradient(
                colors: [
                  AppColors.pitchGreen.withOpacity(0.85),
                  AppColors.pitchGreen.withOpacity(0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.push('/events/$tournamentId/schedule'),
            ),
            const Gap(10),

            // Teams button — all teams & their squads in one place
            _actionCard(
              context,
              icon: Icons.groups_rounded,
              title: 'Teams',
              subtitle: '${teams.length} teams • tap to view squads',
              gradient: LinearGradient(
                colors: [
                  AppColors.vibrantPurple.withOpacity(0.85),
                  AppColors.vibrantPurple.withOpacity(0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => _showTeamsSheet(context, teams, state),
            ),
            const Gap(10),

            // Description / Rules / Requirements (read-only dialogs)
            if (tournament.description != null &&
                tournament.description!.isNotEmpty) ...[
              _actionCard(
                context,
                icon: Icons.description,
                title: 'Description',
                subtitle: 'About this tournament',
                gradient: LinearGradient(
                  colors: [
                    AppColors.vibrantBlue.withOpacity(0.8),
                    AppColors.vibrantBlue.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () =>
                    _showInfoDialog(context, 'Description', tournament.description!),
              ),
              const Gap(10),
            ],
            if (tournament.tournamentRules != null &&
                tournament.tournamentRules!.isNotEmpty) ...[
              _actionCard(
                context,
                icon: Icons.gavel,
                title: 'Rules',
                subtitle: 'Tournament rules & guidelines',
                gradient: LinearGradient(
                  colors: [
                    AppColors.vibrantRed.withOpacity(0.8),
                    AppColors.vibrantRed.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => _showInfoDialog(
                    context, 'Rules', tournament.tournamentRules!),
              ),
              const Gap(10),
            ],
            if (tournament.tournamentRequirements != null &&
                tournament.tournamentRequirements!.isNotEmpty) ...[
              _actionCard(
                context,
                icon: Icons.assignment,
                title: 'Requirements',
                subtitle: 'Eligibility & requirements',
                gradient: LinearGradient(
                  colors: [
                    AppColors.vibrantCyan.withOpacity(0.8),
                    AppColors.vibrantCyan.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => _showInfoDialog(
                    context, 'Requirements', tournament.tournamentRequirements!),
              ),
              const Gap(10),
            ],

            // Matches section
            if (matches.isNotEmpty) ...[
              _sectionHeader(cs, 'Matches'),
              const Gap(8),
              ...matches.map((m) => GestureDetector(
                    onTap: () => context.push('/spectator/match/${m.id}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
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
                            style:
                                AppTextStyles.labelSmall(cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.grey, size: 18),
                        ],
                      ),
                    ),
                  )),
              const Gap(16),
            ],
            const Gap(32),
          ],
        ),
      ),
    );
  }

  /// Stat tile rendered inside the merged hero card (on the gradient).
  Widget _heroStatTile({
    required String emoji,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const Gap(2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const Gap(2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center),
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

  /// Read-only info card button (view in the spectator portion — nothing
  /// editable).
  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
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
                  Text(title,
                      style: AppTextStyles.titleSmall(Colors.white)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const Gap(2),
                  Text(subtitle,
                      style:
                          AppTextStyles.labelSmall(Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: Text(title,
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(body,
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// Prize/entry-fee tile rendered inside the merged hero card.
  Widget _heroPrizeTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const Gap(2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const Gap(2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet listing every team of the tournament with its squad. Each
  /// team card gets its own gradient color.
  void _showTeamsSheet(
      BuildContext context, List<ScorerTeam> teams, SpectatorHomeState state) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    _sectionHeader(cs, 'Teams & Squads (${teams.length})'),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: teams.isEmpty
                    ? Center(
                        child: Text('No teams added yet.',
                            style:
                                AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: teams.length,
                        itemBuilder: (_, i) => _TeamGradientCard(
                          team: teams[i],
                          players: state.playersForTeam(teams[i].id),
                          gradient: AppColors.cardGradients[
                              i % AppColors.cardGradients.length],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Distinct gradients so every team card in the sheet has its own colour.
class _TeamGradientCard extends StatelessWidget {
  final ScorerTeam team;
  final List<ScorerPlayer> players;
  final LinearGradient gradient;

  const _TeamGradientCard({
    required this.team,
    required this.players,
    required this.gradient,
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
    final short = team.shortCode.isNotEmpty
        ? team.shortCode
            .substring(0, team.shortCode.length > 3 ? 3 : team.shortCode.length)
            .toUpperCase()
        : 'T';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(short,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        title: Text(team.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${players.length} squad players • ${team.ownerName ?? 'No owner'}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (players.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No players registered yet.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            )
          else
            ...players.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${p.jerseyNumber ?? '-'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(p.name,
                            style:
                                const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(_roleLabel(p.role),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
