// lib/ui/scorer/all_matches/view/all_matches_screen.dart
// "Start Scoring" tab — lists every match (tournament + local) with search.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

class AllMatchesScreen extends ConsumerStatefulWidget {
  final bool onlyFriendly;
  const AllMatchesScreen({super.key, this.onlyFriendly = false});

  @override
  ConsumerState<AllMatchesScreen> createState() => _AllMatchesScreenState();
}

class _AllMatchesScreenState extends ConsumerState<AllMatchesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final uid = user?.id;

    final allMatches = await repo.getMatches();
    final tournaments = await repo.getTournaments();
    final teams = await repo.getAllTeams();

    final matches = (uid == null || uid.isEmpty)
        ? allMatches
        : allMatches.where((m) => m.createdBy == uid).toList();

    if (!mounted) return;
    setState(() {
      _matches = matches;
      _tournaments = tournaments;
      _teamNames = {for (final t in teams) t.id: t.name};
      _isLoading = false;
    });
  }

  List<ScorerMatch> get _filtered {
    var list = _matches;
    if (widget.onlyFriendly) {
      list = list.where((m) => m.tournamentId == 't_custom').toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((m) {
      final a = _teamNames[m.team1Id]?.toLowerCase() ?? '';
      final b = _teamNames[m.team2Id]?.toLowerCase() ?? '';
      return a.contains(q) ||
          b.contains(q) ||
          m.venue.toLowerCase().contains(q);
    }).toList();
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

  List<_TournamentGroup> get _groups {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;
    final groups = <_TournamentGroup>[];
    final byTournament = <String, List<ScorerMatch>>{};

    for (final match in filtered) {
      byTournament.putIfAbsent(match.tournamentId, () => []).add(match);
    }

    final sortedTournamentIds = byTournament.keys.toList()
      ..sort((a, b) => _tournamentName(a, l10n)
          .toLowerCase()
          .compareTo(_tournamentName(b, l10n).toLowerCase()));

    for (final tournamentId in sortedTournamentIds) {
      groups.add(_TournamentGroup(
        tournamentId: tournamentId,
        tournamentName: _tournamentName(tournamentId, l10n),
        matches: byTournament[tournamentId]!
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      ));
    }

    return groups;
  }

  String _resultSummary(AppLocalizations l10n) {
    return '${_matches.length} ${l10n.translate('matches')}';
  }

  Future<void> _deleteMatch(ScorerMatch match, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text(l10n.translate('delete_match'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          '${l10n.translate('delete_match_permanently')} (${_teamName(match.team1Id)} vs ${_teamName(match.team2Id)})',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.background,
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
                  colors: [AppColors.pitchGreen, Color(0xFF1A7A3E)],
                ),
              ),
              child: const Icon(Icons.sports_cricket_rounded,
                  color: Colors.white, size: 20),
            ),
            const Gap(10),
            Text(
              l10n.translate('start_scoring_title'),
              style: TextStyle(
                  color: cs.onBackground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_hint'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor:
                          Theme.of(context).inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _resultSummary(l10n),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(l10n.translate('no_matches_found'),
                              style: const TextStyle(color: Colors.white54)))
                      : RefreshIndicator(
                          color: AppColors.pitchGreen,
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _groups.length,
                            itemBuilder: (_, i) {
                              final group = _groups[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 10, top: 4),
                                    child: Text(
                                      group.tournamentName,
                                      style: TextStyle(
                                          color: cs.onBackground,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  ...group.matches.map((match) => _MatchTile(
                                        match: match,
                                        teamName: _teamName,
                                        onTap: () {
                                          if (match.status ==
                                                  MatchStatus.completed) {
                                            // A completed match has no active
                                            // live session — show its summary.
                                            context.push(
                                                '/scorer/match-summary?matchId=${match.id}');
                                            return;
                                          }
                                          if (match.status ==
                                                  MatchStatus.inProgress ||
                                              match.status ==
                                                  MatchStatus.live) {
                                            context
                                                .push('/scorer/live-scoring');
                                          } else {
                                            context.push(
                                                '/scorer/matches/${match.id}/squad');
                                          }
                                        },
                                        onDelete: () =>
                                            _deleteMatch(match, l10n),
                                        l10n: l10n,
                                      )),
                                  const Gap(16),
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _TournamentGroup {
  final String tournamentId;
  final String tournamentName;
  final List<ScorerMatch> matches;

  const _TournamentGroup(
      {required this.tournamentId,
      required this.tournamentName,
      required this.matches});
}

class _MatchTile extends StatelessWidget {
  final ScorerMatch match;
  final String Function(String) teamName;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final AppLocalizations l10n;

  const _MatchTile({
    required this.match,
    required this.teamName,
    required this.onTap,
    required this.onDelete,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inProgress;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String statusText = match.status.name.toUpperCase();
    if (isLive) statusText = l10n.translate('live');
    if (match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.scheduled)
      statusText = l10n.translate('upcoming');
    if (match.status == MatchStatus.completed)
      statusText = l10n.translate('completed');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const Gap(4),
                  Text(
                    '${match.format.name.toUpperCase()} • ${match.overs} ${l10n.translate('overs')} • ${match.venue}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      ),
    );
  }
}
