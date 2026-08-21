// lib/ui/scorer/matches/view/scorer_matches_screen.dart
// "Matches" tab — two filter tabs: Friendly and Tournament matches.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
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

class _ScorerMatchesScreenState extends ConsumerState<ScorerMatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ScorerMatch> _matches = [];
  List<ScorerTournament> _tournaments = [];
  Map<String, String> _teamNames = {};
  bool _isLoading = true;

  final Map<String, _FixtureEntry> _fixtureEntries = {};
  final Map<String, String> _stageNameByMatch = {};
  final Set<String> _scheduledMatchIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    ref.listenManual(scorerDataVersionProvider, (_, __) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final uid = user?.id;

    final allMatches = await repo.getMatches();
    final tournaments = await repo.getTournaments();
    final teams = await repo.getAllTeams();

    final fixtureMatches = <ScorerMatch>[];
    final fixtureEntries = <String, _FixtureEntry>{};
    final stageNameByMatch = <String, String>{};
    final scheduledMatchIds = <String>{};

    for (final tournament in tournaments) {
      if (uid != null && uid.isNotEmpty &&
          tournament.createdBy != uid && tournament.ownerId != uid) {
        continue;
      }
      final stages = await repo.getSchedule(tournament.id);
      for (final stage in stages) {
        for (final fx in stage.fixtures) {
          final teamA = fx.resolvedTeamAId;
          final teamB = fx.resolvedTeamBId;
          if (teamA == null || teamB == null) continue;

          if (fx.linkedMatchId != null) {
            stageNameByMatch[fx.linkedMatchId!] = stage.name;
            scheduledMatchIds.add(fx.linkedMatchId!);
          } else {
            for (final m in allMatches) {
              if (m.tournamentId == tournament.id &&
                  ((m.team1Id == teamA && m.team2Id == teamB) ||
                      (m.team1Id == teamB && m.team2Id == teamA))) {
                stageNameByMatch[m.id] = stage.name;
                scheduledMatchIds.add(m.id);
              }
            }
          }

          if (fx.linkedMatchId != null &&
              allMatches.any((m) => m.id == fx.linkedMatchId)) {
            continue;
          }
          final virtualId = 'fx_${fx.id}';
          fixtureMatches.add(ScorerMatch(
            id: virtualId,
            tournamentId: tournament.id,
            team1Id: teamA,
            team2Id: teamB,
            venue: fx.venue ?? tournament.venue,
            dateTime: fx.scheduledDateTime ?? DateTime(0),
            format: tournament.format,
            overs: tournament.customOvers,
            status: switch (fx.status) {
              FixtureStatus.live => MatchStatus.live,
              FixtureStatus.completed => MatchStatus.completed,
              FixtureStatus.pending || FixtureStatus.ready => MatchStatus.scheduled,
            },
            playingXI1: const [],
            playingXI2: const [],
            currentInnings: 1,
            createdBy: tournament.createdBy,
          ));
          fixtureEntries[virtualId] = _FixtureEntry(
              fixture: fx, tournamentId: tournament.id, stageName: stage.name);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _matches = [
        ...allMatches.where((m) => uid == null || uid.isEmpty || m.createdBy == uid),
        ...fixtureMatches,
      ];
      _tournaments = tournaments;
      _teamNames = {for (final t in teams) t.id: t.name};
      _fixtureEntries..clear()..addAll(fixtureEntries);
      _stageNameByMatch..clear()..addAll(stageNameByMatch);
      _scheduledMatchIds..clear()..addAll(scheduledMatchIds);
      _isLoading = false;
    });
  }

  String _teamName(String id) => _teamNames[id] ?? id;

  String _tournamentName(String tournamentId, AppLocalizations l10n) {
    final t = _tournaments.where((t) => t.id == tournamentId).firstOrNull;
    return t?.name ??
        (tournamentId == 't_custom' ? l10n.translate('local_match') : l10n.translate('unknown'));
  }

  bool _isFriendly(ScorerMatch m) =>
      m.tournamentId == 't_custom' && !_scheduledMatchIds.contains(m.id);

  List<ScorerMatch> get _friendlyLive => _matches
      .where((m) => _isFriendly(m) &&
          (m.status == MatchStatus.live || m.status == MatchStatus.inProgress))
      .toList();

  List<ScorerMatch> get _friendlyUpcoming => _matches
      .where((m) => _isFriendly(m) &&
          (m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<ScorerMatch> get _friendlyCompleted => _matches
      .where((m) => _isFriendly(m) &&
          (m.status == MatchStatus.completed || m.status == MatchStatus.abandoned))
      .toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  Map<String, Map<String, List<ScorerMatch>>> get _tournamentGroups {
    final result = <String, Map<String, List<ScorerMatch>>>{};
    for (final m in _matches) {
      if (_isFriendly(m) || m.tournamentId == 't_custom') continue;
      final entry = _fixtureEntries[m.id];
      var stageName = _stageNameByMatch[m.id] ?? entry?.stageName;
      if (stageName == null || stageName.isEmpty || stageName == 'General') {
        stageName = m.status == MatchStatus.completed ? 'Completed' : 'Tournament Matches';
      }
      result
          .putIfAbsent(m.tournamentId, () => {})
          .putIfAbsent(stageName, () => [])
          .add(m);
    }
    for (final byStage in result.values) {
      for (final matches in byStage.values) {
        matches.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
    }
    return result;
  }

  void _openMatch(ScorerMatch match) {
    final entry = _fixtureEntries[match.id];
    if (entry != null) {
      _openFixture(entry.fixture, entry.tournamentId);
      return;
    }
    if (match.status == MatchStatus.completed) {
      context.push('/scorer/match-summary?matchId=${match.id}');
      return;
    }
    if (match.status == MatchStatus.inProgress || match.status == MatchStatus.live) {
      context.push('/scorer/live-scoring');
    } else {
      context.push('/scorer/matches/${match.id}/squad');
    }
  }

  Future<void> _openFixture(ScheduleFixture fixture, String tournamentId) async {
    final l10n = AppLocalizations.of(context);
    final match = await ref
        .read(scorerRepositoryProvider)
        .findOrCreateMatchForFixture(tournamentId: tournamentId, fixture: fixture);
    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.translate('awaiting_result'))));
      return;
    }
    _openMatch(match);
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.liveRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.translate('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(scorerRepositoryProvider).deleteMatch(match.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('match_deleted')), backgroundColor: AppColors.liveRed),
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
            style: AppTextStyles.titleMedium(cs.onSurface)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.pitchGreen,
          indicatorWeight: 3,
          labelColor: AppColors.pitchGreenLight,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: l10n.translate('friendly_matches')),
            Tab(text: l10n.translate('tournament_matches')),
          ],
        ),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendlyTab(l10n, cs),
                _buildTournamentTab(l10n, cs),
              ],
            ),
    );
  }

  Widget _buildFriendlyTab(AppLocalizations l10n, ColorScheme cs) {
    final live = _friendlyLive;
    final upcoming = _friendlyUpcoming;
    final completed = _friendlyCompleted;

    if (live.isEmpty && upcoming.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_cricket_rounded, size: 72, color: AppColors.charcoal400),
            const Gap(16),
            Text(l10n.translate('no_friendly_matches'),
                style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(6),
            Text(l10n.translate('create_match_squads'),
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.pitchGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (live.isNotEmpty) ...[
            _sectionHeader(cs, l10n.translate('live')),
            ...live.map((m) => _tile(m, l10n)),
          ],
          if (upcoming.isNotEmpty) ...[
            _sectionHeader(cs, l10n.translate('upcoming')),
            ...upcoming.map((m) => _tile(m, l10n)),
          ],
          if (completed.isNotEmpty) ...[
            _sectionHeader(cs, l10n.translate('completed')),
            ...completed.map((m) => _tile(m, l10n)),
          ],
        ],
      ),
    );
  }

  Widget _buildTournamentTab(AppLocalizations l10n, ColorScheme cs) {
    final groups = _tournamentGroups;

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.charcoal400),
            const Gap(16),
            Text(l10n.translate('no_tournament_matches'),
                style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(6),
            Text(l10n.translate('create_first_tournament'),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final tournamentIds = groups.keys.toList()
      ..sort((a, b) => _tournamentName(a, l10n).toLowerCase()
          .compareTo(_tournamentName(b, l10n).toLowerCase()));

    return RefreshIndicator(
      color: AppColors.pitchGreen,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          for (final tId in tournamentIds) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.floodlightGoldLight, size: 18),
                  const Gap(6),
                  Expanded(
                    child: Text(_tournamentName(tId, l10n),
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            for (final stageName in (groups[tId] ?? {}).keys) ...[
              _stageHeader(stageName),
              for (final match in (groups[tId]?[stageName] ?? []))
                _tile(match, l10n, stageNameOverride: stageName),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tile(ScorerMatch match, AppLocalizations l10n, {String? stageNameOverride}) {
    final entry = _fixtureEntries[match.id];
    final stageName = stageNameOverride ??
        (match.tournamentId == 't_custom'
            ? null
            : (_stageNameByMatch[match.id] ?? entry?.stageName));
    return _MatchTile(
      match: match,
      teamName: _teamName,
      tournamentName: (id) => _tournamentName(id, l10n),
      stageName: stageName,
      onTap: () => _openMatch(match),
      onDelete: () => _deleteMatch(match, l10n),
      onLongPress: entry == null ? () => _deleteMatch(match, l10n) : null,
      showDelete: entry == null,
      l10n: l10n,
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16,
              decoration: BoxDecoration(color: AppColors.pitchGreenLight, borderRadius: BorderRadius.circular(2))),
          const Gap(8),
          Text(title, style: AppTextStyles.titleMedium(cs.onSurface).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _stageHeader(String stageName) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(color: AppColors.floodlightGoldLight, borderRadius: BorderRadius.circular(2))),
          const Gap(8),
          Text(stageName,
              style: const TextStyle(color: AppColors.floodlightGoldLight,
                  fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final ScorerMatch match;
  final String Function(String) teamName;
  final String Function(String) tournamentName;
  final String? stageName;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onLongPress;
  final bool showDelete;
  final AppLocalizations l10n;

  const _MatchTile({
    required this.match,
    required this.teamName,
    required this.tournamentName,
    this.stageName,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
    required this.showDelete,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live || match.status == MatchStatus.inProgress;
    final canStart = match.status == MatchStatus.upcoming || match.status == MatchStatus.scheduled;
    final isCompleted = match.status == MatchStatus.completed || match.status == MatchStatus.abandoned;

    String statusText = match.status.name.toUpperCase();
    if (isLive) { statusText = l10n.translate('live'); }
    if (match.status == MatchStatus.upcoming || match.status == MatchStatus.scheduled) {
      statusText = l10n.translate('upcoming');
    }
    if (match.status == MatchStatus.completed) {
      statusText = l10n.translate('completed');
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
                  child: Text('${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const Gap(8),
                if (showDelete && !isCompleted)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                    tooltip: l10n.translate('delete'),
                    onPressed: onDelete,
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive ? AppColors.liveRed.withValues(alpha: 0.35) : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Gap(6),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: AppColors.floodlightGoldLight, size: 14),
                const Gap(4),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: tournamentName(match.tournamentId),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      children: [
                        if (stageName != null)
                          TextSpan(
                            text: ' • $stageName',
                            style: const TextStyle(color: AppColors.floodlightGoldLight,
                                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                          ),
                      ],
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
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
                  child: Text(match.venue,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (canStart)
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FixtureEntry {
  final ScheduleFixture fixture;
  final String tournamentId;
  final String? stageName;

  const _FixtureEntry({
    required this.fixture,
    required this.tournamentId,
    this.stageName,
  });
}
