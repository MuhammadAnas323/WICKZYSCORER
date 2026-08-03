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

class AllMatchesScreen extends ConsumerStatefulWidget {
  const AllMatchesScreen({super.key});

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

  List<ScorerMatch> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _matches;
    return _matches.where((m) {
      final a = _teamNames[m.team1Id]?.toLowerCase() ?? '';
      final b = _teamNames[m.team2Id]?.toLowerCase() ?? '';
      return a.contains(q) ||
          b.contains(q) ||
          m.venue.toLowerCase().contains(q);
    }).toList();
  }

  String _teamName(String id) => _teamNames[id] ?? id;

  String _tournamentName(String tournamentId) {
    final tournament =
        _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    return tournament?.name ?? 'Unknown Tournament';
  }

  List<_TournamentGroup> get _groups {
    final filtered = _filtered;
    final groups = <_TournamentGroup>[];
    final byTournament = <String, List<ScorerMatch>>{};

    for (final match in filtered) {
      byTournament.putIfAbsent(match.tournamentId, () => []).add(match);
    }

    final sortedTournamentIds = byTournament.keys.toList()
      ..sort((a, b) => _tournamentName(a)
          .toLowerCase()
          .compareTo(_tournamentName(b).toLowerCase()));

    for (final tournamentId in sortedTournamentIds) {
      groups.add(_TournamentGroup(
        tournamentId: tournamentId,
        tournamentName: _tournamentName(tournamentId),
        matches: byTournament[tournamentId]!
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      ));
    }

    return groups;
  }

  String get _resultSummary {
    return '${_matches.length} match${_matches.length == 1 ? '' : 'es'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
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
            const Text(
              'Start Scoring',
              style: TextStyle(
                  color: Colors.white,
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search matches, teams, venue…',
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
                      fillColor: AppColors.darkSurface,
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
                      _resultSummary,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Text('No matches found',
                              style: TextStyle(color: Colors.white54)))
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
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  ...group.matches.map((match) => _MatchTile(
                                        match: match,
                                        teamName: _teamName,
                                        onTap: () {
                                          if (match.status ==
                                                  MatchStatus.inProgress ||
                                              match.status ==
                                                  MatchStatus.live ||
                                              match.status ==
                                                  MatchStatus.completed) {
                                            context
                                                .push('/scorer/live-scoring');
                                          } else {
                                            context.push(
                                                '/scorer/matches/${match.id}/squad');
                                          }
                                        },
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

  const _MatchTile(
      {required this.match, required this.teamName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inProgress;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const Gap(4),
                  Text(
                    '${match.format.name.toUpperCase()} • ${match.overs} overs • ${match.venue}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLive
                    ? AppColors.liveRed.withValues(alpha: 0.2)
                    : AppColors.pitchGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isLive ? 'LIVE' : match.status.name.toUpperCase(),
                style: TextStyle(
                  color: isLive ? AppColors.liveRed : AppColors.pitchGreenLight,
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
