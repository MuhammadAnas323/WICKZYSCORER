// lib/ui/scorer/matches/view/scorer_matches_screen.dart
// "Matches" tab — lists every match (tournament + local) and offers a way to
// create a new one. Tapping an upcoming match opens the squad setup screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class ScorerMatchesScreen extends ConsumerStatefulWidget {
  const ScorerMatchesScreen({super.key});

  @override
  ConsumerState<ScorerMatchesScreen> createState() =>
      _ScorerMatchesScreenState();
}

class _ScorerMatchesScreenState extends ConsumerState<ScorerMatchesScreen> {
  List<ScorerMatch> _matches = [];
  List<ScorerTournament> _tournaments = [];
  Map<String, String> _teamNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    ref.listenManual(scorerDataVersionProvider, (_, __) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final matches = await repo.getMatches();
    final tournaments = await repo.getTournaments();
    final teams = await repo.getAllTeams();
    if (!mounted) return;
    setState(() {
      _matches = matches;
      _tournaments = tournaments;
      _teamNames = {for (final t in teams) t.id: t.name};
      _isLoading = false;
    });
  }

  String _teamName(String id) => _teamNames[id] ?? id;

  String _tournamentName(String tournamentId, AppLocalizations l10n) {
    final tournament =
        _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    return tournament?.name ??
        (tournamentId == 't_custom'
            ? l10n.translate('local_match')
            : 'Unknown');
  }

  void _openMatch(ScorerMatch match) {
    if (match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live ||
        match.status == MatchStatus.completed) {
      context.push('/scorer/live-scoring');
    } else {
      context.push('/scorer/matches/${match.id}/squad');
    }
  }

  Future<void> _deleteMatch(ScorerMatch match, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(l10n.translate('delete_match'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          '${l10n.translate('delete_confirm')} (${_teamName(match.team1Id)} vs ${_teamName(match.team2Id)})',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.translate('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.liveRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.translate('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(scorerRepositoryProvider);
    await repo.deleteMatch(match.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Match deleted'), backgroundColor: AppColors.liveRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.translate('matches'),
            style: AppTextStyles.titleMedium(cs.onBackground)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scorer/friendly-matches-hub'),
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        tooltip: l10n.translate('add_match'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _matches.isEmpty
              ? _emptyState(l10n)
              : RefreshIndicator(
                  color: AppColors.pitchGreen,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _matches.length,
                    itemBuilder: (_, i) {
                      final match = _matches[i];
                      return _MatchTile(
                        match: match,
                        teamName: _teamName,
                        tournamentName: (id) => _tournamentName(id, l10n),
                        onTap: () => _openMatch(match),
                        onDelete: () => _deleteMatch(match, l10n),
                        l10n: l10n,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_cricket_rounded,
              size: 72, color: AppColors.charcoal400),
          const Gap(16),
          Text(
            l10n.translate('no_matches'),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          Text(
            l10n.translate('create_match_squads'),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Gap(24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(l10n.translate('add_match'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => context.push('/scorer/friendly-matches-hub'),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final ScorerMatch match;
  final String Function(String) teamName;
  final String Function(String) tournamentName;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final AppLocalizations l10n;

  const _MatchTile({
    required this.match,
    required this.teamName,
    required this.tournamentName,
    required this.onTap,
    required this.onDelete,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inProgress;
    final canStart = match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.scheduled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    String statusText = match.status.name.toUpperCase();
    if (isLive) statusText = l10n.translate('live');
    if (match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.scheduled)
      statusText = l10n.translate('upcoming');
    if (match.status == MatchStatus.completed)
      statusText = l10n.translate('completed');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 18),
                  tooltip: l10n.translate('delete'),
                  onPressed: onDelete,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.liveRed.withValues(alpha: 0.2)
                        : AppColors.pitchGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: isLive
                          ? AppColors.liveRed
                          : (isDark
                              ? AppColors.pitchGreenLight
                              : AppColors.pitchGreen),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(6),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: AppColors.floodlightGold.withValues(alpha: 0.8),
                    size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    tournamentName(match.tournamentId),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(2),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    '${match.format.name.toUpperCase()} • ${match.overs} ${l10n.translate('overs')} • ${match.venue}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canStart)
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white38, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
