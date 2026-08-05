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

class TournamentUpcomingMatchesScreen extends ConsumerStatefulWidget {
  const TournamentUpcomingMatchesScreen({super.key});

  @override
  ConsumerState<TournamentUpcomingMatchesScreen> createState() =>
      _TournamentUpcomingMatchesScreenState();
}

class _TournamentUpcomingMatchesScreenState
    extends ConsumerState<TournamentUpcomingMatchesScreen> {
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

    // Only matches that are not t_custom and have upcoming status
    // and created by current user
    final matches = allMatches.where((m) {
      if (uid != null && uid.isNotEmpty && m.createdBy.isNotEmpty && m.createdBy != uid) {
        return false;
      }
      return m.tournamentId != 't_custom' &&
          (m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled);
    }).toList();

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

  String _tournamentName(String tournamentId, AppLocalizations l10n) {
    final tournament =
        _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    return tournament?.name ?? 'Unknown Tournament';
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
                  colors: [AppColors.floodlightGold, Colors.orangeAccent],
                ),
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: Colors.black, size: 20),
            ),
            const Gap(10),
            Text(
              'Upcoming Tournament Matches',
              style: TextStyle(
                  color: cs.onBackground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 18),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.floodlightGold))
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
                const Gap(8),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(l10n.translate('no_matches_found'),
                              style: const TextStyle(color: Colors.white54)))
                      : RefreshIndicator(
                          color: AppColors.floodlightGold,
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
                                          context.push(
                                              '/scorer/matches/${match.id}/squad');
                                        },
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
  final AppLocalizations l10n;

  const _MatchTile({
    required this.match,
    required this.teamName,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.pitchGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.translate('upcoming'),
                style: TextStyle(
                  color: isDark
                      ? AppColors.pitchGreenLight
                      : AppColors.pitchGreen,
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
