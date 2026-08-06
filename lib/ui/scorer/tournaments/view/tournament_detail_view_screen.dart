import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class TournamentDetailViewScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentDetailViewScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<TournamentDetailViewScreen> createState() =>
      _TournamentDetailViewScreenState();
}

class _TournamentDetailViewScreenState
    extends ConsumerState<TournamentDetailViewScreen> {
  ScorerTournament? _tournament;
  List<ScorerTeam> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final tournament = await repo.getTournament(widget.tournamentId);
    final teams = await repo.getTeamsByTournament(widget.tournamentId);
    setState(() {
      _tournament = tournament;
      _teams = teams;
      _isLoading = false;
    });
  }

  Future<void> _togglePayment(ScorerTeam team) async {
    final repo = ref.read(scorerRepositoryProvider);
    await repo.toggleTeamPaymentStatus(team.id);
    await _loadData();
  }

  Future<void> _deleteTeam(ScorerTeam team) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(l10n.translate('delete'),
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text('Remove "${team.name}" from this tournament?',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.translate('cancel'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(scorerRepositoryProvider);
      await repo.deleteTeam(team.id);
      await _loadData();
      ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    }
  }

  Future<void> _deleteTournament() async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(l10n.translate('delete'),
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
            l10n.translate('delete_match_permanently'),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.translate('cancel'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(scorerRepositoryProvider)
        .deleteTournament(widget.tournamentId);
    ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    if (mounted) context.go('/scorer/tournaments');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onBackground;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(color: textColor)),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.pitchGreen)),
      );
    }

    final t = _tournament;
    if (t == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: BackButton(color: textColor)),
        body: Center(
            child: Text(l10n.translate('match_not_found'),
                style: TextStyle(color: subTextColor))),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(t.name,
            style: AppTextStyles.headlineSmall(textColor),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                color: AppColors.pitchGreenLight),
            tooltip: l10n.translate('edit_tournament'),
            onPressed: () async {
              await context.push('/scorer/tournaments/${t.id}/edit');
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: l10n.translate('delete'),
            onPressed: _deleteTournament,
          ),
          const Gap(4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, fontWeight: FontWeight.bold),
        label: Text(l10n.translate('teams'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await context.push('/scorer/teams?tournamentId=${t.id}');
          _loadData();
        },
      ),
      body: RefreshIndicator(
        color: AppColors.pitchGreen,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament Overview Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.pitchGreen.withOpacity(0.25),
                      surfaceColor
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: AppColors.floodlightGold, size: 28),
                        const Gap(10),
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pitchGreen.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.format.name.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.pitchGreenLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: subTextColor.withOpacity(0.7), size: 16),
                        const Gap(4),
                        Text(t.venue,
                            style: TextStyle(
                                color: subTextColor, fontSize: 13)),
                        const Gap(16),
                        Icon(Icons.sports_cricket,
                            color: subTextColor.withOpacity(0.7), size: 16),
                        const Gap(4),
                        Text('${t.customOvers} ${l10n.translate('overs')}',
                            style: TextStyle(
                                color: subTextColor, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Financial & Cash Prizes Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.floodlightGold.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined,
                            color: AppColors.floodlightGold, size: 20),
                        const Gap(8),
                        Text(l10n.translate('cash_prizes'),
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ],
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        _prizeTile(
                            l10n.translate('entry_fees'),
                            t.entryFee != null
                                ? r'$ ' '${t.entryFee!.toStringAsFixed(0)}'
                                : 'Free',
                            Colors.blueAccent, surfaceColor, subTextColor),
                        const Gap(8),
                        _prizeTile(
                            '${l10n.translate('cash_prizes')} 🏆',
                            t.winnerPrize != null
                                ? '\$ ${t.winnerPrize!.toStringAsFixed(0)}'
                                : 'TBD',
                            AppColors.floodlightGold, surfaceColor, subTextColor),
                        const Gap(8),
                        _prizeTile(
                            'Runner-Up 🥈',
                            t.runnerUpPrize != null
                                ? '\$ ${t.runnerUpPrize!.toStringAsFixed(0)}'
                                : 'TBD',
                            subTextColor, surfaceColor, subTextColor),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Match Schedule Card
              _InfoCardButton(
                title: 'Match Schedule',
                subtitle: 'Stages, fixtures & auto-advancement',
                icon: Icons.calendar_month,
                gradient: LinearGradient(
                  colors: [AppColors.pitchGreen.withOpacity(0.8), AppColors.pitchGreen.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () async {
                  await context.push('/scorer/tournaments/${t.id}/schedule');
                  _loadData();
                },
                cs: theme.colorScheme,
              ),
              const Gap(16),

              // Rules, Requirements & Description Buttons
              if ((t.description != null && t.description!.isNotEmpty) ||
                  (t.tournamentRules != null && t.tournamentRules!.isNotEmpty) ||
                  (t.tournamentRequirements != null && t.tournamentRequirements!.isNotEmpty)) ...[
                if (t.description != null && t.description!.isNotEmpty) ...[
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
                          content: SingleChildScrollView(child: Text(t.description!)),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                        ),
                      );
                    },
                    cs: theme.colorScheme,
                  ),
                  const Gap(8),
                ],
                if (t.tournamentRules != null && t.tournamentRules!.isNotEmpty) ...[
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
                          content: SingleChildScrollView(child: Text(t.tournamentRules!)),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                        ),
                      );
                    },
                    cs: theme.colorScheme,
                  ),
                  const Gap(8),
                ],
                if (t.tournamentRequirements != null && t.tournamentRequirements!.isNotEmpty) ...[
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
                          content: SingleChildScrollView(child: Text(t.tournamentRequirements!)),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                        ),
                      );
                    },
                    cs: theme.colorScheme,
                  ),
                  const Gap(8),
                ],
                const Gap(16),
              ],

              // Teams Button
              _InfoCardButton(
                title: '${l10n.translate('teams')} & Squads',
                subtitle: '${_teams.length} team${_teams.length == 1 ? '' : 's'} registered',
                icon: Icons.groups_rounded,
                gradient: LinearGradient(
                  colors: [
                    AppColors.floodlightGold.withOpacity(0.85),
                    AppColors.floodlightGold.withOpacity(0.55),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => _showTeamsSheet(context, t, l10n),
                cs: theme.colorScheme,
              ),

              const Gap(80),
            ],
          ),
        ),
      ),
    );
  }

  void _showTeamsSheet(
    BuildContext context,
    dynamic t,
    dynamic l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(context);
            final textColor = theme.colorScheme.onSurface;
            final subTextColor = theme.colorScheme.onSurfaceVariant;
            final surfaceColor = theme.colorScheme.surface;
            final cs = theme.colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
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
                            color: subTextColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
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
                                    AppColors.pitchGreen.withOpacity(0.7),
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
                              style: AppTextStyles.titleLarge(textColor)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            // Add team button
                            TextButton.icon(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await context.push(
                                    '/scorer/teams?tournamentId=${t.id}');
                                _loadData();
                              },
                              icon: const Icon(Icons.add,
                                  size: 16, color: AppColors.pitchGreenLight),
                              label: const Text('Add',
                                  style: TextStyle(
                                      color: AppColors.pitchGreenLight,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: cs.outlineVariant, height: 1),
                      // Teams list
                      Expanded(
                        child: _teams.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.group_off_outlined,
                                        size: 56,
                                        color: subTextColor.withOpacity(0.3)),
                                    const Gap(12),
                                    Text('No teams added yet.',
                                        style: AppTextStyles.bodyMedium(
                                            subTextColor)),
                                    const Gap(16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.pitchGreen,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () async {
                                        Navigator.of(ctx).pop();
                                        await context.push(
                                            '/scorer/teams?tournamentId=${t.id}');
                                        _loadData();
                                      },
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Add Team'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollCtrl,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                itemCount: _teams.length,
                                itemBuilder: (_, i) {
                                  final team = _teams[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.floodlightGold
                                              .withOpacity(0.08),
                                          surfaceColor,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.floodlightGold
                                              .withOpacity(0.25)),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                      onTap: () async {
                                        Navigator.of(ctx).pop();
                                        await context.push(
                                            '/scorer/teams/${team.id}/players');
                                        _loadData();
                                      },
                                      onLongPress: () {
                                        Navigator.of(ctx).pop();
                                        _deleteTeam(team);
                                      },
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.floodlightGold,
                                              AppColors.pitchGreen,
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
                                                          : team
                                                              .shortCode.length)
                                                  .toUpperCase()
                                              : 'T',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      title: Text(team.name,
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      subtitle: Text(
                                          '${team.playerIds.length} squad players',
                                          style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 11)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Payment badge
                                          GestureDetector(
                                            onTap: () {
                                              _togglePayment(team);
                                              setSheetState(() {});
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: team.isEntryFeePaid
                                                    ? AppColors.pitchGreen
                                                        .withOpacity(0.2)
                                                    : Colors.red
                                                        .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: team.isEntryFeePaid
                                                      ? AppColors.pitchGreenLight
                                                      : Colors.redAccent,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    team.isEntryFeePaid
                                                        ? Icons.check_circle
                                                        : Icons.pending,
                                                    color: team.isEntryFeePaid
                                                        ? AppColors
                                                            .pitchGreenLight
                                                        : Colors.redAccent,
                                                    size: 12,
                                                  ),
                                                  const Gap(3),
                                                  Text(
                                                    team.isEntryFeePaid
                                                        ? l10n.translate('paid')
                                                        : l10n.translate(
                                                            'unpaid'),
                                                    style: TextStyle(
                                                      color: team.isEntryFeePaid
                                                          ? AppColors
                                                              .pitchGreenLight
                                                          : Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Edit button
                                          IconButton(
                                            icon: Icon(Icons.edit_outlined,
                                                color: subTextColor
                                                    .withOpacity(0.7),
                                                size: 18),
                                            tooltip: 'Edit Team',
                                            onPressed: () async {
                                              Navigator.of(ctx).pop();
                                              await context.push(
                                                  '/scorer/teams/${team.id}/edit');
                                              _loadData();
                                            },
                                          ),
                                        ],
                                      ),
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
      },
    );
  }


  Widget _prizeTile(String label, String value, Color color, Color surfaceColor, Color subTextColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor ?? surfaceColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const Gap(2),
            Text(label,
                style: TextStyle(color: subTextColor, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
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
