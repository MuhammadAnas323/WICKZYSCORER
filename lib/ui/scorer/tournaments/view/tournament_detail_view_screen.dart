import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
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
              GestureDetector(
                onTap: () async {
                  await context.push('/scorer/tournaments/${t.id}/schedule');
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.pitchGreen.withOpacity(0.18),
                        surfaceColor
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.pitchGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          color: AppColors.pitchGreenLight, size: 26),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.translate('manual_schedule'),
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const Gap(2),
                            Text('Stages, fixtures & auto-advancement',
                                style: TextStyle(
                                    color: subTextColor, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: subTextColor.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const Gap(24),

              // Teams Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${l10n.translate('teams')} (${_teams.length})',
                      style: AppTextStyles.titleLarge(textColor)),
                ],
              ),
              const Gap(12),

              if (_teams.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 48, color: subTextColor),
                      const Gap(12),
                      Text(
                        l10n.translate('no_matches'),
                        style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        l10n.translate('create_match_squads'),
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      const Gap(16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pitchGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await context
                              .push('/scorer/teams?tournamentId=${t.id}');
                          _loadData();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Team'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _teams.length,
                  separatorBuilder: (_, __) => const Gap(10),
                  itemBuilder: (ctx, i) {
                    final team = _teams[i];
                    return GestureDetector(
                      onTap: () async {
                        await context.push('/scorer/teams/${team.id}/players');
                        _loadData();
                      },
                      onLongPress: () => _deleteTeam(team),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.pitchGreen.withOpacity(0.2),
                              child: Text(
                                team.shortCode.isNotEmpty
                                    ? team.shortCode
                                    : 'T',
                                style: const TextStyle(
                                    color: AppColors.pitchGreenLight,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(team.name,
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Text('${team.playerIds.length} Squad Players',
                                      style: TextStyle(
                                          color: subTextColor, fontSize: 11)),
                                ],
                              ),
                            ),
                            // Payment Toggle Chip
                            GestureDetector(
                              onTap: () => _togglePayment(team),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: team.isEntryFeePaid
                                      ? AppColors.pitchGreen.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
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
                                          ? AppColors.pitchGreenLight
                                          : Colors.redAccent,
                                      size: 14,
                                    ),
                                    const Gap(4),
                                    Text(
                                      team.isEntryFeePaid ? l10n.translate('paid') : l10n.translate('unpaid'),
                                      style: TextStyle(
                                        color: team.isEntryFeePaid
                                            ? AppColors.pitchGreenLight
                                            : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  color: subTextColor.withOpacity(0.7), size: 20),
                              tooltip: 'Team Details',
                              onPressed: () async {
                                await context
                                    .push('/scorer/teams/${team.id}/edit');
                                _loadData();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

              const Gap(80),
            ],
          ),
        ),
      ),
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
