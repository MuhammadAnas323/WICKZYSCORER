// lib/ui/scorer/all_matches/view/all_matches_screen.dart
// Friendly match selection & management screen with visible search and player details.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
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
  Map<String, List<ScorerPlayer>> _teamPlayers = {};
  bool _isLoading = true;

  final Set<String> _scheduledMatchIds = {};

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

    final allMatches = await repo.getMatches(forCurrentUserOnly: true);
    final tournaments = await repo.getTournaments(forCurrentUserOnly: true);
    final teams = await repo.getAllTeams(forCurrentUserOnly: true);
    final players = await repo.getAllPlayers(forCurrentUserOnly: true);

    final scheduledMatchIds = <String>{};
    for (final tournament in tournaments) {
      final stages = await repo.getSchedule(tournament.id);
      for (final stage in stages) {
        for (final fx in stage.fixtures) {
          if (fx.linkedMatchId != null) {
            scheduledMatchIds.add(fx.linkedMatchId!);
          }
        }
      }
    }

    final matches = (uid == null || uid.isEmpty)
        ? allMatches
        : allMatches.where((m) => m.createdBy == uid).toList();

    final teamPlayers = <String, List<ScorerPlayer>>{};
    for (final p in players) {
      teamPlayers.putIfAbsent(p.teamId, () => []).add(p);
    }

    if (!mounted) return;
    setState(() {
      _matches = matches;
      _tournaments = tournaments;
      _teamNames = {for (final t in teams) t.id: t.name};
      _teamPlayers = teamPlayers;
      _scheduledMatchIds
        ..clear()
        ..addAll(scheduledMatchIds);
      _isLoading = false;
    });
  }

  List<ScorerMatch> get _filtered {
    var list = _matches;
    if (widget.onlyFriendly) {
      list = list
          .where((m) =>
              m.tournamentId == 't_custom' &&
              !_scheduledMatchIds.contains(m.id))
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((m) {
      final a = _teamNames[m.team1Id]?.toLowerCase() ?? '';
      final b = _teamNames[m.team2Id]?.toLowerCase() ?? '';
      final playersA = (_teamPlayers[m.team1Id] ?? [])
          .map((p) => p.name.toLowerCase())
          .join(' ');
      final playersB = (_teamPlayers[m.team2Id] ?? [])
          .map((p) => p.name.toLowerCase())
          .join(' ');

      return a.contains(q) ||
          b.contains(q) ||
          playersA.contains(q) ||
          playersB.contains(q) ||
          m.venue.toLowerCase().contains(q);
    }).toList();
  }

  String _teamName(String id) => _teamNames[id] ?? id;

  List<ScorerPlayer> _getPlayers(String teamId) => _teamPlayers[teamId] ?? [];

  String _tournamentName(String tournamentId, AppLocalizations l10n) {
    final tournament =
        _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    return tournament?.name ??
        (tournamentId == 't_custom'
            ? l10n.translate('local_match')
            : l10n.translate('unknown'));
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
    return '${_filtered.length} ${l10n.translate('matches')}';
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
      SnackBar(
          content: Text(l10n.translate('match_deleted')), backgroundColor: AppColors.liveRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

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
                  colors: [AppColors.pitchGreen, Color(0xFF0D47A1)],
                ),
              ),
              child: const Icon(Icons.sports_cricket_rounded,
                  color: Colors.white, size: 20),
            ),
            const Gap(10),
            Text(
              widget.onlyFriendly ? 'Select Friendly Match' : l10n.translate('start_scoring_title'),
              style: TextStyle(
                  color: cs.onBackground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : Column(
              children: [
                // ── Visible & Styled Search Bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(color: cs.onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search match, team or player name...',
                        hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                        prefixIcon:
                            Icon(Icons.search, color: cs.primary),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: cs.onSurfaceVariant),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(l10n.translate('no_matches_found'),
                              style: TextStyle(color: cs.onSurfaceVariant)))
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
                                        players1: _getPlayers(match.team1Id),
                                        players2: _getPlayers(match.team2Id),
                                        onTap: () {
                                          if (match.status ==
                                                  MatchStatus.completed) {
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
  final List<ScorerPlayer> players1;
  final List<ScorerPlayer> players2;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final AppLocalizations l10n;

  const _MatchTile({
    required this.match,
    required this.teamName,
    required this.players1,
    required this.players2,
    required this.onTap,
    required this.onDelete,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inProgress;

    String statusText = match.status.name.toUpperCase();
    if (isLive) statusText = l10n.translate('live');
    if (match.status == MatchStatus.upcoming ||
        match.status == MatchStatus.scheduled)
      statusText = l10n.translate('upcoming');
    if (match.status == MatchStatus.completed)
      statusText = l10n.translate('completed');

    final name1 = teamName(match.team1Id);
    final name2 = teamName(match.team2Id);
    final squad1 = players1.map((p) => p.name).join(', ');
    final squad2 = players2.map((p) => p.name).join(', ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradientFor(match.id),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name1  vs  $name2',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      const Gap(4),
                      Text(
                        '${match.overs} ${l10n.translate('overs')} • ${match.venue}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  tooltip: l10n.translate('delete'),
                  onPressed: onDelete,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLive
                        ? AppColors.liveRed.withValues(alpha: 0.85)
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
            // ── Display Teams & Players ──────────────────────────────────────
            const Divider(color: Colors.white24, height: 16, thickness: 0.8),
            _TeamPlayersRow(teamName: name1, playersText: squad1),
            const SizedBox(height: 6),
            _TeamPlayersRow(teamName: name2, playersText: squad2),
          ],
        ),
      ),
    );
  }
}

class _TeamPlayersRow extends StatelessWidget {
  final String teamName;
  final String playersText;

  const _TeamPlayersRow({required this.teamName, required this.playersText});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.groups, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: '$teamName: ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: playersText.isNotEmpty ? playersText : 'No players added yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
