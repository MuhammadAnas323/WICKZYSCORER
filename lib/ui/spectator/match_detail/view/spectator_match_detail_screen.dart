import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';

class SpectatorMatchDetailScreen extends ConsumerStatefulWidget {
  final String matchId;
  const SpectatorMatchDetailScreen({super.key, required this.matchId});

  @override
  ConsumerState<SpectatorMatchDetailScreen> createState() =>
      _SpectatorMatchDetailScreenState();
}

class _SpectatorMatchDetailScreenState
    extends ConsumerState<SpectatorMatchDetailScreen> {
  String? _selectedTeamId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spectatorHomeViewModelProvider);
    // Live Firestore match document: reflects the scorer's ball-by-ball
    // updates (runs, balls, wickets) in real time while the match is live.
    // Until the first snapshot arrives it falls back to the cached list.
    final liveMatch =
        ref.watch(scorerMatchDocStreamProvider(widget.matchId)).valueOrNull;
    final cs = Theme.of(context).colorScheme;

    final match =
        liveMatch ??
        state.matches.where((m) => m.id == widget.matchId).firstOrNull;

    if (state.isLoading) {
      return Scaffold(appBar: AppBar(), body: const MatchListSkeleton());
    }

    if (match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Match not found')),
      );
    }

    // Keep the filter valid if teams change; default to team 1.
    if (_selectedTeamId == null ||
        (_selectedTeamId != match.team1Id && _selectedTeamId != match.team2Id)) {
      _selectedTeamId = match.team1Id;
    }

    final liveData = state.liveDataFor(match.id);
    final isLive = liveData != null ||
        match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live;
    final tournament = state.tournamentById(match.tournamentId);

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text(
          tournament?.name ?? 'Match Details',
          style: AppTextStyles.headlineSmall(cs.onSurface),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(spectatorHomeViewModelProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(state, match, isLive),
            const Gap(16),
            _infoCard(context, match, state, tournament?.name),
            const Gap(16),
            if (match.status == MatchStatus.completed)
              _awardsCard(context, state, match),
            const Gap(16),
            // Team filter — applies to both the scorecard and the squads below.
            _teamFilterChips(context, state, match),
            const Gap(12),
            if (match.innings1 != null ||
                match.innings2 != null ||
                match.superOverInnings1 != null) ...[
              Text('Full Scorecard',
                  style: AppTextStyles.titleLarge(cs.onSurface)),
              const Gap(8),
              ..._filteredInnings(context, state, match),
              const Gap(16),
            ],
            Text('Squads', style: AppTextStyles.titleLarge(cs.onSurface)),
            const Gap(8),
            _squadCard(context, state, match, _selectedTeamId ?? match.team1Id),
            const Gap(16),
            if (match.status == MatchStatus.completed &&
                match.resultSummary != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: AppColors.success, size: 22),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        match.resultSummary!,
                        style: AppTextStyles.bodyMedium(cs.onSurface)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  /// Innings where the selected team batted — including any super over.
  List<Widget> _filteredInnings(
      BuildContext context, SpectatorHomeState st, ScorerMatch match) {
    final selected = _selectedTeamId ?? match.team1Id;
    final innings = <Innings>[
      if (match.innings1 != null &&
          match.innings1!.battingTeamId == selected)
        match.innings1!,
      if (match.innings2 != null &&
          match.innings2!.battingTeamId == selected)
        match.innings2!,
      if (match.superOverInnings1 != null &&
          match.superOverInnings1!.battingTeamId == selected)
        match.superOverInnings1!,
      if (match.superOverInnings2 != null &&
          match.superOverInnings2!.battingTeamId == selected)
        match.superOverInnings2!,
    ];
    return innings
        .map((inn) => _inningsSection(context, st, inn,
            _inningsLabel(inn, match.innings1, match.innings2)))
        .toList();
  }

  String _inningsLabel(Innings inn, Innings? inn1, Innings? inn2) {
    if (inn1 != null && inn.id == inn1.id) return '1st Innings';
    if (inn2 != null && inn.id == inn2.id) return '2nd Innings';
    return '⚡ Super Over';
  }

  Widget _teamFilterChips(
      BuildContext context, SpectatorHomeState st, ScorerMatch match) {
    return Row(
      children: [
        Expanded(
          child: _filterChip(context,
              label: st.teamName(match.team1Id),
              selected: (_selectedTeamId ?? match.team1Id) == match.team1Id,
              onTap: () => setState(() => _selectedTeamId = match.team1Id)),
        ),
        const Gap(8),
        Expanded(
          child: _filterChip(context,
              label: st.teamName(match.team2Id),
              selected: (_selectedTeamId ?? match.team1Id) == match.team2Id,
              onTap: () => setState(() => _selectedTeamId = match.team2Id)),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.pitchGreen.withOpacity(0.25)
              : cs.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: selected ? AppColors.pitchGreen : cs.outline),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: selected ? AppColors.pitchGreenLight : cs.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// Awarded players (Player of the Match / Best Batsman / Best Bowler) that
  /// belong to the selected team, with their optional prize text.
  Widget _awardsCard(
      BuildContext context, SpectatorHomeState st, ScorerMatch match) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedTeamId ?? match.team1Id;
    final awards = <({String title, String? playerId, String? prize})>[
      (title: 'Player of the Match', playerId: match.playerOfTheMatchId, prize: match.playerOfTheMatchPrize),
      (title: 'Best Batsman', playerId: match.bestBatsmanId, prize: match.bestBatsmanPrize),
      (title: 'Best Bowler', playerId: match.bestBowlerId, prize: match.bestBowlerPrize),
    ];
    final visible =
        awards.where((a) => a.playerId != null && _playerTeamId(st, match, a.playerId!) == selected).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.floodlightGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: AppColors.floodlightGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.floodlightGold, size: 18),
              const Gap(8),
              Text('Awards',
                  style: AppTextStyles.titleSmall(cs.onSurface)
                      .copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(10),
          for (final a in visible) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(st.playerName(a.playerId!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (a.prize != null && a.prize!.isNotEmpty)
                          Text(a.prize!,
                              style: const TextStyle(
                                  color: AppColors.floodlightGold,
                                  fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _playerTeamId(
      SpectatorHomeState st, ScorerMatch match, String playerId) {
    if (st.playersForTeam(match.team1Id).any((p) => p.id == playerId)) {
      return match.team1Id;
    }
    if (st.playersForTeam(match.team2Id).any((p) => p.id == playerId)) {
      return match.team2Id;
    }
    return null;
  }

  // ── Hero scoreboard ────────────────────────────────────────────────────

  Widget _heroCard(SpectatorHomeState st, ScorerMatch match, bool isLive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroCardGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLive) ...[
                const LiveBadge(),
                const SizedBox(width: 8),
              ],
              Text(_formatLabel(match),
                  style: AppTextStyles.labelMedium(Colors.white70)),
            ],
          ),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: _heroTeam(
                  short: st.teamShort(match.team1Id),
                  name: st.teamName(match.team1Id),
                  score: _heroScore(match, match.team1Id),
                  sub: _heroSub(match, match.team1Id),
                  isBatting: isLive && match.battingTeamId == match.team1Id,
                  isRight: false,
                ),
              ),
              Text('vs', style: AppTextStyles.bodyMedium(Colors.white54)),
              Expanded(
                child: _heroTeam(
                  short: st.teamShort(match.team2Id),
                  name: st.teamName(match.team2Id),
                  score: _heroScore(match, match.team2Id),
                  sub: _heroSub(match, match.team2Id),
                  isBatting: isLive && match.battingTeamId == match.team2Id,
                  isRight: true,
                ),
              ),
            ],
          ),
          const Gap(16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    match.venue,
                    style: AppTextStyles.bodySmall(Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTeam({
    required String short,
    required String name,
    required String score,
    String? sub,
    required bool isBatting,
    required bool isRight,
  }) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isRight) ...[_badge(short), const SizedBox(width: 10)],
            Flexible(
              child: Text(
                isBatting ? '$name ▸' : name,
                style: AppTextStyles.titleMedium(Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRight) ...[const SizedBox(width: 10), _badge(short)],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          score,
          style: AppTextStyles.scoreMedium(
              isBatting ? AppColors.floodlightGold : Colors.white),
        ),
        if (sub != null)
          Text(sub, style: AppTextStyles.labelSmall(Colors.white54)),
      ],
    );
  }

  Widget _badge(String short) {
    return Container(
      width: 40,
      height: 40,
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
      alignment: Alignment.center,
      child: Text(
        short.length > 3
            ? short.substring(0, 3).toUpperCase()
            : short.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _formatLabel(ScorerMatch match) {
    switch (match.format) {
      case MatchFormat.t20:
        return 'T20 • ${match.overs} overs';
      case MatchFormat.odi:
        return 'ODI • ${match.overs} overs';
      case MatchFormat.test:
        return 'TEST';
      case MatchFormat.custom:
        return '${match.overs}-OVER';
    }
  }

  /// Best available score line for [teamId]: the innings (main or super over)
  /// where that team batted, read from the freshest live match document.
  String _heroScore(ScorerMatch match, String teamId) {
    for (final inn in [
      match.innings1,
      match.innings2,
      match.superOverInnings1,
      match.superOverInnings2,
    ]) {
      if (inn != null && inn.battingTeamId == teamId) {
        return '${inn.totalRuns}/${inn.wickets} (${inn.overs.toStringAsFixed(1)})';
      }
    }
    return '—';
  }

  /// Current run rate while [teamId] is batting (live matches only).
  String? _heroSub(ScorerMatch match, String teamId) {
    if (match.status != MatchStatus.inProgress &&
        match.status != MatchStatus.live) {
      return null;
    }
    if (match.battingTeamId != teamId) return null;
    final inn = match.currentInningsData;
    if (inn == null || inn.legalBallsDelivered == 0) return null;
    return 'RR ${(inn.totalRuns * 6 / inn.legalBallsDelivered).toStringAsFixed(2)}';
  }

  String _runRateLabel(Innings? inn) {
    if (inn == null || inn.legalBallsDelivered == 0) return '—';
    return (inn.totalRuns * 6 / inn.legalBallsDelivered).toStringAsFixed(2);
  }

  // ── Info card ──────────────────────────────────────────────────────────

  Widget _infoCard(BuildContext context, ScorerMatch match,
      SpectatorHomeState st, String? tournamentName) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          _infoRow(cs, Icons.emoji_events_rounded, 'Tournament',
              tournamentName ?? 'Custom Match'),
          _infoRow(cs, Icons.calendar_today_rounded, 'Scheduled',
              '${match.dateTime.day}/${match.dateTime.month}/${match.dateTime.year}'),
          _infoRow(cs, Icons.access_time_rounded, 'Status',
              match.status.name.toUpperCase()),
          if (match.tossWinnerId != null)
            _infoRow(cs, Icons.adjust_rounded, 'Toss',
                '${st.teamName(match.tossWinnerId!)} won the toss'),
          if (match.note != null && match.note!.isNotEmpty)
            _infoRow(cs, Icons.notes_rounded, 'Note', match.note!),
        ],
      ),
    );
  }

  Widget _infoRow(ColorScheme cs, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.pitchGreenLight, size: 18),
          const Gap(10),
          Text(label, style: AppTextStyles.labelMedium(cs.onSurfaceVariant)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTextStyles.bodyMedium(cs.onSurface)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Full scorecard ─────────────────────────────────────────────────────

  Widget _inningsSection(
      BuildContext context, SpectatorHomeState st, Innings inn, String title) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Text(title,
                    style: AppTextStyles.titleSmall(cs.onSurfaceVariant)),
                const Spacer(),
                Text(
                    '${st.teamShort(inn.battingTeamId)} ${inn.totalRuns}/${inn.wickets}',
                    style: AppTextStyles.titleMedium(cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
                'Overs ${inn.overs.toStringAsFixed(1)} • Run rate ${_runRateLabel(inn)}',
                style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
          ),
          const Gap(8),
          _battingCard(st, inn),
          const Divider(color: Colors.white12, height: 12),
          _bowlingCard(st, inn),
          const Divider(color: Colors.white12, height: 12),
          _commentaryCard(st, inn),
        ],
      ),
    );
  }

  Widget _battingCard(SpectatorHomeState st, Innings inn) {
    final acc = <String, _BatAccum>{};
    for (final ball in inn.balls) {
      if (ball.batsmanId.isEmpty) continue;
      final a = acc.putIfAbsent(ball.batsmanId, () => _BatAccum());
      if (ball.isLegalBall) {
        a.balls++;
        a.runs += ball.runs;
        if (ball.isBoundary && ball.runs == 4) a.fours++;
        if (ball.isSix) a.sixes++;
      }
    }
    final entries = acc.entries.toList()
      ..sort((x, y) => y.value.runs.compareTo(x.value.runs));
    final rows = entries.map((e) {
      final a = e.value;
      return <String>[
        st.playerName(e.key),
        '${a.runs}',
        '${a.balls}',
        '${a.fours}',
        '${a.sixes}',
        a.balls > 0 ? (a.runs * 100 / a.balls).toStringAsFixed(2) : '—',
      ];
    }).toList();
    return _tableCard(
      title: 'Batting',
      headers: const ['Batter', 'R', 'B', '4s', '6s', 'SR'],
      widths: [3, 1, 1, 1, 1, 1.2],
      rows: rows,
    );
  }

  Widget _bowlingCard(SpectatorHomeState st, Innings inn) {
    final acc = <String, _BowlAccum>{};
    for (final ball in inn.balls) {
      final b = acc.putIfAbsent(ball.bowlerId, () => _BowlAccum());
      b.runs += ball.totalRuns;
      if (ball.isWicket) b.wickets++;
      if (ball.isLegalBall) b.legalBalls++;
    }
    final rows = acc.entries.map((e) {
      final a = e.value;
      final balls = a.legalBalls;
      final overs = balls ~/ 6 + (balls % 6) / 10;
      final economy = balls > 0 ? (a.runs * 6) / balls : 0.0;
      return <String>[
        st.playerName(e.key),
        overs.toStringAsFixed(1),
        '${a.maidens}',
        '${a.runs}',
        '${a.wickets}',
        economy.toStringAsFixed(2),
      ];
    }).toList();
    return _tableCard(
      title: 'Bowling',
      headers: const ['Bowler', 'O', 'M', 'R', 'W', 'Econ'],
      widths: [1, 1, 1, 1, 1, 1.2],
      rows: rows,
    );
  }

  Widget _commentaryCard(SpectatorHomeState st, Innings inn) {
    final balls = inn.balls.reversed.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Over by Over',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Gap(8),
          if (balls.isEmpty)
            const Text('No deliveries yet.',
                style: TextStyle(color: Colors.white38, fontSize: 12))
          else
            ...balls.map((b) => _commentaryRow(st, b)),
        ],
      ),
    );
  }

  Widget _commentaryRow(SpectatorHomeState st, BallEvent b) {
    final color = b.isWicket
        ? Colors.redAccent
        : b.isSix
            ? Colors.amber
            : b.isBoundary
                ? Colors.green
                : AppColors.charcoal200;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${b.overNumber}.${b.ballInOver}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${st.playerName(b.batsmanId)} — ${_ballText(b)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String _ballText(BallEvent b) {
    if (b.isWicket) return 'Wicket!';
    if (b.extrasType == ExtrasType.wide) return '${b.extrasRuns} wide';
    if (b.extrasType == ExtrasType.noBall) return '${b.extrasRuns} no ball';
    if (b.extrasType == ExtrasType.bye) return '${b.extrasRuns} bye';
    if (b.extrasType == ExtrasType.legBye) return '${b.extrasRuns} leg bye';
    if (b.isSix) return 'SIX!';
    if (b.isBoundary) return 'FOUR';
    return '${b.runs} run${b.runs == 1 ? '' : 's'}';
  }

  Widget _tableCard({
    required String title,
    required List<String> headers,
    required List<double> widths,
    required List<List<String>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.pitchGreenLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 0; i < headers.length; i++)
              Expanded(
                flex: widths[i].round(),
                child: Text(headers[i],
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const Divider(color: Colors.white12, height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(
                    flex: widths[i].round(),
                    child: Text(row[i],
                        style: TextStyle(
                          color: i == 0 ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              i == 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Squads ─────────────────────────────────────────────────────────────

  Widget _squadCard(BuildContext context, SpectatorHomeState st,
      ScorerMatch match, String teamId) {
    final cs = Theme.of(context).colorScheme;
    final xi = teamId == match.team1Id ? match.playingXI1 : match.playingXI2;
    final teamPlayers = st.playersForTeam(teamId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded,
                  color: AppColors.pitchGreenLight, size: 18),
              const Gap(8),
              Text('${st.teamName(teamId)} — Playing XI',
                  style: AppTextStyles.titleSmall(cs.onSurface)
                      .copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const Gap(10),
          for (final id in xi) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.pitchGreenLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(st.playerName(id),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13))),
                  Text(
                      _roleLabel(
                          teamPlayers.where((p) => p.id == id).firstOrNull),
                      style: const TextStyle(color: Colors.grey, fontSize: 9)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _roleLabel(ScorerPlayer? p) {
    if (p == null) return '';
    switch (p.role) {
      case PlayerRole.batsman:
        return 'BAT';
      case PlayerRole.bowler:
        return 'BOWL';
      case PlayerRole.allRounder:
        return 'AR';
      case PlayerRole.wicketKeeper:
        return 'WK';
    }
  }
}

// Small accumulation helpers.
class _BatAccum {
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
}

class _BowlAccum {
  int legalBalls = 0;
  int runs = 0;
  int wickets = 0;
  int maidens = 0;
}
