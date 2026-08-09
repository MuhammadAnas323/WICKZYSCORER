// lib/ui/scorer/tournaments/view/tournament_upcoming_matches_screen.dart
// Start Scoring → Tournaments flow.
//
// Mode A (no [tournamentId]): lists the scorer's tournaments and whether a
//   schedule exists for each. Tapping a tournament opens its schedule screen
//   (Mode B) directly, skipping the Tournament Details page.
//
// Mode B ([tournamentId] set): shows the tournament's schedule stage by stage
//   (each stage's fixtures) plus any standalone scheduled matches. Tapping a
//   ready fixture creates/finds its match and starts the scoring workflow
//   (squad setup → toss → live scoring). A tournament with no schedule shows
//   an empty state that links to the Schedule Builder.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_schedule.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/shared_widgets/tournament_card.dart';

class TournamentUpcomingMatchesScreen extends ConsumerStatefulWidget {
  final String? tournamentId;

  const TournamentUpcomingMatchesScreen({super.key, this.tournamentId});

  @override
  ConsumerState<TournamentUpcomingMatchesScreen> createState() =>
      _TournamentUpcomingMatchesScreenState();
}

class _TournamentUpcomingMatchesScreenState
    extends ConsumerState<TournamentUpcomingMatchesScreen> {
  List<ScorerMatch> _matches = [];
  List<ScorerTournament> _tournaments = [];
  Map<String, String> _teamNames = {};
  Map<String, List<ScheduleStage>> _schedules = {};
  bool _isLoading = true;
  bool _opening = false;

  bool get _isTournamentList => widget.tournamentId == null;

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

    // Owned tournaments only — a scorer always sees the ones they created and
    // nothing from other users (legacy/empty createdBy entries are excluded).
    final myTournaments = tournaments.where((t) {
      if (uid != null && uid.isNotEmpty) {
        return t.createdBy == uid || t.ownerId == uid;
      }
      return true;
    }).toList();

    // Only the current user's upcoming/scheduled tournament matches
    // (standalone friendly matches use the pseudo 't_custom' id).
    final matches = allMatches.where((m) {
      if (uid != null && uid.isNotEmpty && m.createdBy != uid) {
        return false;
      }
      return m.tournamentId != 't_custom' &&
          (m.status == MatchStatus.upcoming ||
              m.status == MatchStatus.scheduled);
    }).toList();

    final schedules = <String, List<ScheduleStage>>{};
    for (final t in myTournaments) {
      schedules[t.id] = await repo.getSchedule(t.id);
    }

    if (!mounted) return;
    setState(() {
      _matches = matches;
      _tournaments = myTournaments;
      _teamNames = {for (final t in teams) t.id: t.name};
      _schedules = schedules;
      _isLoading = false;
    });
  }

  String _teamName(String id) => _teamNames[id] ?? id;

  ScorerTournament? _tournamentById(String id) =>
      _tournaments.where((t) => t.id == id).firstOrNull;

  List<ScheduleStage> get _selectedTournamentStages =>
      _schedules[widget.tournamentId] ?? const [];

  /// Fixtures whose two sides are resolved plus standalone scheduled matches.
  int _playableCount(String tournamentId) {
    var count = 0;
    for (final s in _schedules[tournamentId] ?? const <ScheduleStage>[]) {
      for (final fx in s.fixtures) {
        if (fx.resolvedTeamAId != null && fx.resolvedTeamBId != null) count++;
      }
    }
    return count + _matches.where((m) => m.tournamentId == tournamentId).length;
  }

  /// True when a schedule has been built (any stage fixture) or any match
  /// exists for the tournament.
  bool _hasScheduleData(String tournamentId) {
    final stages = _schedules[tournamentId] ?? const <ScheduleStage>[];
    if (stages.any((s) => s.fixtures.isNotEmpty)) return true;
    return _matches.any((m) => m.tournamentId == tournamentId);
  }

  void _onTournamentTap(ScorerTournament tournament) {
    // Always open this tournament's schedule/upcoming screen directly.
    context.push('/scorer/tournament-upcoming-matches?tournamentId=${tournament.id}');
  }

  List<ScorerMatch> get _standaloneUpcomingMatches {
    final id = widget.tournamentId;
    final linked = <String>{
      for (final s in _selectedTournamentStages)
        for (final fx in s.fixtures)
          if (fx.linkedMatchId != null) fx.linkedMatchId!,
    };
    final list = _matches.where((m) =>
        m.tournamentId == id &&
        !linked.contains(m.id) &&
        (m.status == MatchStatus.upcoming || m.status == MatchStatus.scheduled)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  void _openMatch(ScorerMatch match) {
    if (match.status == MatchStatus.completed) {
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

  /// Tapping a ready fixture starts its scoring process: find or create the
  /// match that backs it, then route it to the right step.
  Future<void> _openFixture(ScheduleFixture fixture) async {
    if (_opening) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _opening = true);
    try {
      final match = await ref.read(scorerRepositoryProvider)
          .findOrCreateMatchForFixture(
            tournamentId: widget.tournamentId!,
            fixture: fixture,
          );
      if (!mounted) return;
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('awaiting_result'))),
        );
        return;
      }
      _openMatch(match);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tournament = widget.tournamentId == null
        ? null
        : _tournamentById(widget.tournamentId!);

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
            Expanded(
              child: Text(
                _isTournamentList
                    ? l10n.translate('select_tournament')
                    : (tournament?.name ?? l10n.translate('upcoming_matches')),
                style: TextStyle(
                    color: cs.onBackground,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.floodlightGold))
          : _isTournamentList
              ? _buildTournamentList()
              : _buildScheduleScreen(),
    );
  }

  // ── Mode A: list of available tournaments ────────────────────────────────
  Widget _buildTournamentList() {
    final l10n = AppLocalizations.of(context);

    if (_tournaments.isEmpty) {
      return _emptyMessage(
        icon: Icons.emoji_events_outlined,
        title: l10n.translate('no_tournaments_available'),
        subtitle: l10n.translate('create_tournament_hint'),
      );
    }

    return RefreshIndicator(
      color: AppColors.floodlightGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _tournaments.length,
        itemBuilder: (_, i) {
          final tournament = _tournaments[i];
          final playable = _playableCount(tournament.id);
          final hasSchedule = _hasScheduleData(tournament.id);
          return TournamentCard(
            tournament: tournament,
            headerBadge: _scheduleBadge(hasSchedule, playable, l10n),
            onTap: () => _onTournamentTap(tournament),
          );
        },
      ),
    );
  }

  Widget _scheduleBadge(
      bool hasSchedule, int playableCount, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = hasSchedule
        ? (isDark ? AppColors.pitchGreenLight : AppColors.pitchGreen)
        : Colors.grey;
    final text = hasSchedule
        ? (playableCount > 0
            ? '$playableCount ${l10n.translate('upcoming')}'
            : l10n.translate('schedule'))
        : l10n.translate('no_schedule');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  // ── Mode B: schedule & upcoming matches for the selected tournament ──────
  Widget _buildScheduleScreen() {
    final l10n = AppLocalizations.of(context);
    final stages =
        _selectedTournamentStages.where((s) => s.fixtures.isNotEmpty).toList();
    final standalone = _standaloneUpcomingMatches;

    if (stages.isEmpty && standalone.isEmpty) {
      return _emptySchedule(l10n);
    }

    return RefreshIndicator(
      color: AppColors.floodlightGold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final stage in stages) _buildStageSection(stage),
          if (standalone.isNotEmpty) ...[
            _sectionHeader(l10n.translate('upcoming_matches')),
            for (var i = 0; i < standalone.length; i++)
              _UpcomingMatchTile(
                match: standalone[i],
                matchNumber: i + 1,
                teamName: _teamName,
                onTap: () => _openMatch(standalone[i]),
                l10n: l10n,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageSection(ScheduleStage stage) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              Icon(
                stage.type == ScheduleStageType.knockout
                    ? Icons.emoji_events_outlined
                    : stage.type == ScheduleStageType.roundRobin
                        ? Icons.repeat_rounded
                        : Icons.more_horiz,
                color: AppColors.pitchGreen,
                size: 18,
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  stage.name,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              Text(
                '${stage.fixtures.length} ${l10n.translate('matches')}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11),
              ),
            ],
          ),
        ),
        for (final fx in stage.fixtures)
          _FixtureTile(
            fixture: fx,
            teamName: _teamName,
            onTap: (fx.resolvedTeamAId != null && fx.resolvedTeamBId != null)
                ? () => _openFixture(fx)
                : null,
            l10n: l10n,
          ),
        const Gap(4),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Text(
        title,
        style: TextStyle(
            color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _emptySchedule(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Gap(80),
          const Icon(Icons.calendar_month_outlined,
              size: 72, color: AppColors.charcoal400),
          const Gap(16),
          Text(
            l10n.translate('no_schedule'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.translate('build_schedule_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const Gap(24),
          Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.floodlightGold,
                foregroundColor: Colors.black,
              ),
              onPressed: () =>
                  context.push('/scorer/tournaments/${widget.tournamentId}'),
              icon: const Icon(Icons.calendar_month),
              label: Text(l10n.translate('build_schedule')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.charcoal400),
          const Gap(16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onBackground, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule fixture tile (Mode B) ─────────────────────────────────────────
class _FixtureTile extends StatelessWidget {
  final ScheduleFixture fixture;
  final String Function(String) teamName;
  final VoidCallback? onTap;
  final AppLocalizations l10n;

  const _FixtureTile({
    required this.fixture,
    required this.teamName,
    required this.onTap,
    required this.l10n,
  });

  String _teamLabel(String? id) =>
      id != null ? teamName(id) : l10n.translate('awaiting_result');

  String _statusText() {
    switch (fixture.status) {
      case FixtureStatus.pending:
        return l10n.translate('awaiting_result');
      case FixtureStatus.ready:
        return l10n.translate('upcoming');
      case FixtureStatus.live:
        return l10n.translate('live');
      case FixtureStatus.completed:
        return l10n.translate('completed');
    }
  }

  Color _statusColor(bool isDark) {
    switch (fixture.status) {
      case FixtureStatus.ready:
        return isDark ? AppColors.pitchGreenLight : AppColors.pitchGreen;
      case FixtureStatus.live:
        return AppColors.liveRed;
      case FixtureStatus.completed:
        return Colors.grey;
      case FixtureStatus.pending:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playable =
        fixture.resolvedTeamAId != null && fixture.resolvedTeamBId != null;
    final local = fixture.scheduledDateTime?.toLocal();
    final statusColor = _statusColor(isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.floodlightGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${l10n.translate('match_number')} #${fixture.order}',
                    style: const TextStyle(
                        color: AppColors.floodlightGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Gap(10),
            Text(
              '${_teamLabel(fixture.resolvedTeamAId)}  vs  '
              '${_teamLabel(fixture.resolvedTeamBId)}',
              style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            if (local != null || fixture.venue != null) ...[
              const Gap(8),
              Row(
                children: [
                  if (local != null) ...[
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.grey, size: 13),
                    const Gap(4),
                    Text(
                      '${local.day}/${local.month}/${local.year}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Gap(12),
                    const Icon(Icons.schedule, color: Colors.grey, size: 13),
                    const Gap(4),
                    Text(
                      '${local.hour.toString().padLeft(2, '0')}:'
                      '${local.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const Gap(12),
                  ],
                  if (fixture.venue != null) ...[
                    const Icon(Icons.location_on,
                        color: Colors.grey, size: 13),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        fixture.venue!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (fixture.isReady && playable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_outline,
                        color: AppColors.floodlightGold, size: 16),
                    const Gap(4),
                    Text(
                      l10n.translate('start_scoring'),
                      style: const TextStyle(
                          color: AppColors.floodlightGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Standalone upcoming match tile (Mode B) ────────────────────────────────
class _UpcomingMatchTile extends StatelessWidget {
  final ScorerMatch match;
  final int matchNumber;
  final String Function(String) teamName;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _UpcomingMatchTile({
    required this.match,
    required this.matchNumber,
    required this.teamName,
    required this.onTap,
    required this.l10n,
  });

  String _statusText() {
    switch (match.status) {
      case MatchStatus.scheduled:
        return l10n.translate('scheduled');
      case MatchStatus.upcoming:
        return l10n.translate('upcoming');
      default:
        return match.status.name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = match.dateTime.toLocal();

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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${l10n.translate('match_number')} #$matchNumber',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(10),
            Text(
              '${teamName(match.team1Id)}  vs  ${teamName(match.team2Id)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const Gap(8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 13),
                const Gap(4),
                Text(
                  '${local.day}/${local.month}/${local.year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Gap(12),
                const Icon(Icons.schedule, color: Colors.white70, size: 13),
                const Gap(4),
                Text(
                  '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Gap(12),
                const Icon(Icons.location_on, color: Colors.white70, size: 13),
                const Gap(4),
                Expanded(
                  child: Text(
                    match.venue,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              '${match.overs} ${l10n.translate('overs')}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
