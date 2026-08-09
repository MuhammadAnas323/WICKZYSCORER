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
import 'package:sportyapp/core/providers/auth_provider.dart';
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
    final user = ref.read(currentUserProvider);
    final uid = user?.id;

    final allMatches = await repo.getMatches();
    final tournaments = await repo.getTournaments();
    final teams = await repo.getAllTeams();
    if (!mounted) return;
    setState(() {
      // Scorer side: only the current user's matches (no empty-createdBy
      // fallback so other users' data never leaks in). All statuses are kept —
      // completed, incompleted, upcoming and live — and grouped into sections
      // in the build below.
      _matches = allMatches
          .where((m) => (uid == null || uid.isEmpty || m.createdBy == uid))
          .toList();
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
            : l10n.translate('unknown'));
  }

  void _openMatch(ScorerMatch match) {
    if (match.status == MatchStatus.completed) {
      // A completed match has no active live session — show its final summary.
      context.push('/scorer/match-summary?matchId=${match.id}');
      return;
    }
    if (match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live) {
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
      SnackBar(
          content: Text(l10n.translate('match_deleted')), backgroundColor: AppColors.liveRed),
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_liveMatches.isNotEmpty) ...[
                        _sectionHeader(context, cs, l10n.translate('live')),
                        ..._liveMatches.map((m) => _tile(context, m, l10n)),
                      ],
                      if (_upcomingMatches.isNotEmpty) ...[
                        _sectionHeader(
                            context, cs, l10n.translate('upcoming')),
                        ..._upcomingMatches.map((m) => _tile(context, m, l10n)),
                      ],
                      if (_completedMatches.isNotEmpty) ...[
                        _sectionHeader(
                            context, cs, l10n.translate('completed')),
                        ..._completedMatches.map((m) => _tile(context, m, l10n)),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<ScorerMatch> get _liveMatches => _matches
      .where((m) =>
          m.status == MatchStatus.inProgress || m.status == MatchStatus.live)
      .toList();

  List<ScorerMatch> get _upcomingMatches => _matches
      .where((m) =>
          m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled)
      .toList();

  List<ScorerMatch> get _completedMatches => _matches
      .where((m) =>
          m.status == MatchStatus.completed ||
          m.status == MatchStatus.abandoned)
      .toList();

  Widget _tile(BuildContext context, ScorerMatch match,
      AppLocalizations l10n) {
    return _MatchTile(
      match: match,
      teamName: _teamName,
      tournamentName: (id) => _tournamentName(id, l10n),
      onTap: () => _openMatch(match),
      onDelete: () => _deleteMatch(match, l10n),
      l10n: l10n,
    );
  }

  Widget _sectionHeader(
      BuildContext context, ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
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
          gradient: AppColors.cardGradientFor(match.id),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
                    style: const TextStyle(
                        color: Colors.white,
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
                        ? AppColors.liveRed.withValues(alpha: 0.35)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
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
                    color: AppColors.floodlightGoldLight,
                    size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    tournamentName(match.tournamentId),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(2),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const Gap(4),
                Expanded(
                  child: Text(
                    match.venue,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canStart)
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white70, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
