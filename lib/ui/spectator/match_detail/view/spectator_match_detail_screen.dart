import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/scorer/ball_event.dart';
import 'package:sportyapp/data/models/scorer/dismissal.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/providers/live_match_providers.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';
import 'package:sportyapp/shared_widgets/live_badge.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/home/viewmodel/spectator_home_viewmodel.dart';
import 'package:sportyapp/ui/spectator/match_detail/viewmodel/match_notification_prefs_provider.dart';

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

    // Keep the filter valid if teams change; default to the active batting team if live, otherwise team 1.
    if (_selectedTeamId == null ||
        (_selectedTeamId != match.team1Id && _selectedTeamId != match.team2Id)) {
      _selectedTeamId = (match.status == MatchStatus.inProgress || match.status == MatchStatus.live)
          ? (match.battingTeamId ?? match.team1Id)
          : match.team1Id;
    }

    // Live transport: RTDB carries the real-time live state (score, strikers,
    // bowler, this over) written by the scorer on every ball. Until the first
    // snapshot arrives, or for matches created by older scorer builds, fall
    // back to deriving the panel from the Firestore match document. Once the
    // match is completed the RTDB node is removed, so the panel switches to the
    // permanent Firestore history — it can never show a stale live score.
    final isLive = match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live;
    final rtdbLive =
        ref.watch(liveMatchDataProvider(widget.matchId)).valueOrNull;
    final liveData =
        isLive ? (rtdbLive ?? liveMatchDataFromMatch(match)) : null;
    final tournament = state.tournamentById(match.tournamentId);

    // Resolve real player names from the self-contained RTDB live payload
    // first (published with the live state), falling back to the spectator's
    // Firestore player list. This is what lets the scorecard/squads render
    // actual names even when this device has not synced the scorer's players.
    final nameOf = _nameResolver(state, liveData);

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
            _heroCard(state, match, isLive, liveData),
            const Gap(16),
            // ── Live players panel (Firestore match doc, real-time every ball) ──
            if (isLive && liveData != null) ...[  
              _livePlayersPanel(context, state, match, liveData, nameOf),
              const Gap(16),
            ],
            _infoCard(context, match, state, tournament?.name),
            const Gap(16),
            _alertsCard(context),
            const Gap(16),
            if (match.status == MatchStatus.completed)
              _awardsCard(context, state, match, nameOf),
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
              ..._filteredInnings(context, state, match, liveData, nameOf),
              const Gap(16),
            ],
            Text('Squads', style: AppTextStyles.titleLarge(cs.onSurface)),
            const Gap(8),
            _squadCard(
                context, state, match, _selectedTeamId ?? match.team1Id, nameOf),
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

  /// Resolves a player's real name, preferring the self-contained RTDB live
  /// payload published by the scorer (which includes every player id → name),
  /// and falling back to the spectator's locally-hydrated player list. This
  /// guarantees real names on the scorecard/squads even when this device has
  /// not synced the scorer's player records from Firestore.
  String Function(String id) _nameResolver(
      SpectatorHomeState st, LiveMatchData? liveData) {
    return (String id) => resolvePlayerName(st, liveData, id);
  }

  /// Innings to display. For live matches, show ALL available innings so
  /// the spectator always sees the current batting/bowling scorecard.
  /// For completed matches, filter by the selected team.
  List<Widget> _filteredInnings(BuildContext context, SpectatorHomeState st,
      ScorerMatch match, LiveMatchData? liveData, String Function(String) nameOf) {
    final isLive = match.status == MatchStatus.inProgress ||
        match.status == MatchStatus.live;
    final selected = _selectedTeamId ?? match.team1Id;

    final innings = <Innings>[];

    if (isLive) {
      // Show all available innings for live matches
      if (match.innings1 != null) innings.add(match.innings1!);
      if (match.innings2 != null) innings.add(match.innings2!);
      if (match.superOverInnings1 != null) innings.add(match.superOverInnings1!);
      if (match.superOverInnings2 != null) innings.add(match.superOverInnings2!);
    } else {
      // Completed/upcoming: filter by selected team (either batting or bowling)
      if (match.innings1 != null &&
          (match.innings1!.battingTeamId == selected || match.innings1!.bowlingTeamId == selected))
        innings.add(match.innings1!);
      if (match.innings2 != null &&
          (match.innings2!.battingTeamId == selected || match.innings2!.bowlingTeamId == selected))
        innings.add(match.innings2!);
      if (match.superOverInnings1 != null &&
          (match.superOverInnings1!.battingTeamId == selected || match.superOverInnings1!.bowlingTeamId == selected))
        innings.add(match.superOverInnings1!);
      if (match.superOverInnings2 != null &&
          (match.superOverInnings2!.battingTeamId == selected || match.superOverInnings2!.bowlingTeamId == selected))
        innings.add(match.superOverInnings2!);
    }

    return innings
        .asMap()
        .entries
        .map((e) => _inningsSection(
            context, st, e.value,
            _inningsLabel(e.value, match.innings1, match.innings2, selected), match,
            liveData, nameOf,
            gradient: AppColors
                .cardGradients[e.key % AppColors.cardGradients.length]))
        .toList();
  }

  String _inningsLabel(Innings inn, Innings? inn1, Innings? inn2, String selectedTeamId) {
    String base = '';
    if (inn1 != null && inn.id == inn1.id) base = '1st Innings';
    else if (inn2 != null && inn.id == inn2.id) base = '2nd Innings';
    else base = '⚡ Super Over';

    if (inn.battingTeamId == selectedTeamId) return '$base (Batting)';
    if (inn.bowlingTeamId == selectedTeamId) return '$base (Bowling)';
    return base;
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
  Widget _awardsCard(BuildContext context, SpectatorHomeState st,
      ScorerMatch match, String Function(String id) nameOf) {
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
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 18),
              const Gap(8),
              Text('Awards',
                  style: AppTextStyles.titleSmall(Colors.white)
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
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(nameOf(a.playerId!),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (a.prize != null && a.prize!.isNotEmpty)
                          Text(a.prize!,
                              style: const TextStyle(
                                  color: Colors.white70,
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

  // ── Live players panel (real-time from RTDB) ──────────────────────────

  Widget _livePlayersPanel(BuildContext context, SpectatorHomeState st,
      ScorerMatch match, LiveMatchData live, String Function(String id) nameOf) {
    final striker = live.striker;
    final nonStriker = live.nonStriker;
    final bowler = live.currentBowler;
    final overBalls = live.thisOverBalls;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.liveCardGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.redAccent, size: 9),
                const SizedBox(width: 6),
                Text('LIVE NOW',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const Spacer(),
                Text(
                  '${live.score.runs}/${live.score.wickets}  (${live.score.overs}.${live.score.balls})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Target / RRR row (2nd innings)
          if (live.target != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  Text('Target: ${live.target}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (live.requiredRunRate != null)
                    Text('RRR: ${live.requiredRunRate!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppColors.floodlightGoldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],

          const Divider(color: Colors.white24, height: 16),

          // Batters
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              children: [
                _livePlayerRow(
                  name: striker.name.isNotEmpty
                      ? striker.name
                      : nameOf(striker.playerId),
                  detail:
                      '${striker.runs} (${striker.balls}) • 4s:${striker.fours} 6s:${striker.sixes}',
                  badge: '★',
                  badgeColor: AppColors.floodlightGold,
                ),
                const SizedBox(height: 6),
                _livePlayerRow(
                  name: nonStriker.name.isNotEmpty
                      ? nonStriker.name
                      : nameOf(nonStriker.playerId),
                  detail:
                      '${nonStriker.runs} (${nonStriker.balls}) • 4s:${nonStriker.fours} 6s:${nonStriker.sixes}',
                  badge: '◇',
                  badgeColor: Colors.white70,
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 14),

          // Bowler
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _livePlayerRow(
              name: bowler.name.isNotEmpty
                  ? bowler.name
                  : nameOf(bowler.playerId),
              detail:
                  '${bowler.oversLabel} ov  ${bowler.runs}R  ${bowler.wickets}W  Econ:${bowler.economy.toStringAsFixed(2)}',
              badge: '⚡',
              badgeColor: AppColors.pitchGreenLight,
            ),
          ),

          // This over
          if (overBalls.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This Over',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Row(
                    children: overBalls.map((label) {
                      final isW = label == 'W';
                      final isSix = label == '6';
                      final isFour = label == '4';
                      final color = isW
                          ? Colors.redAccent
                          : isSix
                              ? Colors.amber
                              : isFour
                                  ? Colors.greenAccent
                                  : Colors.white70;
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withOpacity(0.5)),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _livePlayerRow({
    required String name,
    required String detail,
    required String badge,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Text(badge,
            style: TextStyle(color: badgeColor, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        Text(detail,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ── Hero scoreboard ────────────────────────────────────────────────────

  Widget _heroCard(
      SpectatorHomeState st, ScorerMatch match, bool isLive, LiveMatchData? live) {
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
              if (isLive) const LiveBadge(),
            ],
          ),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: _heroTeam(
                  short: st.teamShort(match.team1Id),
                  name: st.teamName(match.team1Id),
                  score: _heroScore(match, match.team1Id, live),
                  sub: _heroSub(match, match.team1Id, live),
                  isBatting: isLive && match.battingTeamId == match.team1Id,
                  isRight: false,
                ),
              ),
              Text('vs', style: AppTextStyles.bodyMedium(Colors.white54)),
              Expanded(
                child: _heroTeam(
                  short: st.teamShort(match.team2Id),
                  name: st.teamName(match.team2Id),
                  score: _heroScore(match, match.team2Id, live),
                  sub: _heroSub(match, match.team2Id, live),
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

  /// Best available score line for [teamId]: the RTDB live payload when that
  /// team is batting, otherwise the innings (main or super over) where the team
  /// batted, read from the freshest Firestore match document.
  String _heroScore(ScorerMatch match, String teamId, [LiveMatchData? live]) {
    if (live != null && live.battingTeamId == teamId) {
      return '${live.score.runs}/${live.score.wickets} '
          '(${live.score.overs}.${live.score.balls})';
    }
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

  /// Current run rate (live matches only), preferring the RTDB payload.
  String? _heroSub(ScorerMatch match, String teamId, [LiveMatchData? live]) {
    if (live != null && live.battingTeamId == teamId) {
      final score = live.score;
      final parts = <String>[];
      if (score.totalBalls > 0) {
        parts.add(
            'RR ${(score.runs * 6 / score.totalBalls).toStringAsFixed(2)}');
      }
      if (live.requiredRunRate != null) {
        parts.add('RRR ${live.requiredRunRate!.toStringAsFixed(2)}');
      }
      return parts.isNotEmpty ? parts.join(' • ') : null;
    }
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradients[2],
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        children: [
          _infoRow(Icons.emoji_events_rounded, 'Tournament',
              tournamentName ?? 'Custom Match'),
          _infoRow(Icons.calendar_today_rounded, 'Scheduled',
              '${match.dateTime.day}/${match.dateTime.month}/${match.dateTime.year}'),
          _infoRow(Icons.access_time_rounded, 'Status',
              match.status.name.toUpperCase()),
          if (match.tossWinnerId != null)
            _infoRow(Icons.adjust_rounded, 'Toss',
                '${st.teamName(match.tossWinnerId!)} won the toss'),
          if (match.note != null && match.note!.isNotEmpty)
            _infoRow(Icons.notes_rounded, 'Note', match.note!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.floodlightGoldLight, size: 18),
          const Gap(10),
          Text(label, style: AppTextStyles.labelMedium(Colors.white70)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: AppTextStyles.bodyMedium(Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ── Match alerts ──────────────────────────────────────────────────────

  /// Bell (ON/OFF) control for per-match push alerts. Each event type
  /// (match start / wickets / match completed) is a separate toggle. Requires a
  /// signed-in spectator; otherwise it offers a sign-in shortcut.
  Widget _alertsCard(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradients[5],
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: AppColors.pitchGreenLight, size: 20),
            const Gap(10),
            const Expanded(
              child: Text(
                'Sign in to get match alerts.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => context.push('/signin'),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    final prefs = ref.watch(matchNotificationPrefsProvider(widget.matchId));
    final notifier =
        ref.read(matchNotificationPrefsProvider(widget.matchId).notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradients[5],
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: AppColors.pitchGreenLight, size: 18),
                const Gap(8),
                Text('Match Alerts',
                    style: AppTextStyles.titleSmall(Colors.white)
                        .copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            value: prefs.enabled,
            activeTrackColor: AppColors.pitchGreen,
            onChanged: (_) => notifier.toggleAlerts(),
          ),
          if (prefs.enabled) ...[
            const Divider(color: Colors.white24, height: 1),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Match start',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: prefs.matchStart,
              activeTrackColor: AppColors.pitchGreen,
              onChanged: (_) => notifier.toggleMatchStart(),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('1st Innings start',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: prefs.firstInningsStart,
              activeTrackColor: AppColors.pitchGreen,
              onChanged: (_) => notifier.toggleFirstInningsStart(),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('2nd Innings start',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: prefs.secondInningsStart,
              activeTrackColor: AppColors.pitchGreen,
              onChanged: (_) => notifier.toggleSecondInningsStart(),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Wickets',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: prefs.wicket,
              activeTrackColor: AppColors.pitchGreen,
              onChanged: (_) => notifier.toggleWicket(),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Match completed',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              value: prefs.matchComplete,
              activeTrackColor: AppColors.pitchGreen,
              onChanged: (_) => notifier.toggleMatchComplete(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Full scorecard ─────────────────────────────────────────────────────

  Widget _inningsSection(BuildContext context, SpectatorHomeState st,
      Innings inn, String title, ScorerMatch match, LiveMatchData? liveData,
      String Function(String id) nameOf,
      {required Gradient gradient}) {
    final selected = _selectedTeamId ?? match.team1Id;
    final isBatting = inn.battingTeamId == selected;
    final isBowling = inn.bowlingTeamId == selected;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.titleSmall(Colors.white70)),
                ),
                Text(
                    '${st.teamShort(inn.battingTeamId)} ${inn.totalRuns}/${inn.wickets}',
                    style: AppTextStyles.titleMedium(Colors.white)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
                'Overs ${inn.overs.toStringAsFixed(1)} • Run rate ${_runRateLabel(inn)}',
                style: AppTextStyles.bodySmall(Colors.white70)),
          ),
          const Gap(8),
          // If a team filter is active, only show the relevant card for that team in this innings.
          if (isBatting) ...[
            _battingCard(context, st, inn, match, liveData, nameOf),
          ] else if (isBowling) ...[
            _bowlingCard(context, st, inn, match, liveData, nameOf),
          ] else ...[
            // No filter or neither team matched (shouldn't happen in 2-team matches), show both.
            _battingCard(context, st, inn, match, liveData, nameOf),
            const Divider(color: Colors.white24, height: 12),
            _bowlingCard(context, st, inn, match, liveData, nameOf),
          ],
          const Divider(color: Colors.white24, height: 12),
          _overByOverCard(inn, nameOf),
        ],
      ),
    );
  }

  String _formatDismissal(SpectatorHomeState st, Dismissal d, String bowlerId,
      String Function(String id) nameOf) {
    final type = d.type;
    final fielder = d.fielderId != null && d.fielderId!.isNotEmpty ? nameOf(d.fielderId!) : null;
    final bowler = bowlerId.isNotEmpty ? nameOf(bowlerId) : null;

    switch (type) {
      case DismissalType.bowled:
        return bowler != null ? 'b $bowler' : 'bowled';
      case DismissalType.caught:
        if (fielder != null && bowler != null) return 'c $fielder b $bowler';
        if (bowler != null) return 'c & b $bowler';
        return 'caught';
      case DismissalType.lbw:
        return bowler != null ? 'lbw b $bowler' : 'lbw';
      case DismissalType.runOut:
        return fielder != null ? 'run out ($fielder)' : 'run out';
      case DismissalType.stumped:
        if (fielder != null && bowler != null) return 'st $fielder b $bowler';
        return 'stumped';
      case DismissalType.hitWicket:
        return bowler != null ? 'hit wicket b $bowler' : 'hit wicket';
      default:
        return 'out';
    }
  }

  Widget _battingCard(BuildContext context, SpectatorHomeState st, Innings inn,
      ScorerMatch match, LiveMatchData? liveData, String Function(String) nameOf) {
    // For the current live innings, use the self-contained scorecard that the
    // scorer published to RTDB — it carries resolved names + stats and updates
    // every ball with no Firestore lag.
    if (liveData != null && match.currentInningsData?.id == inn.id) {
      final rows = liveData.battingCard.map((b) {
        final name = b.name.isNotEmpty ? b.name : nameOf(b.playerId);
        return <String>[
          b.onStrike ? '$name *' : name,
          b.status.isEmpty ? 'batting' : b.status,
          '${b.runs}',
          '${b.balls}',
          '${b.fours}',
          '${b.sixes}',
          b.strikeRate.toStringAsFixed(2),
        ];
      }).toList();
      return _tableCard(
        title: 'Batting',
        headers: const ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
        widths: [2.5, 2.0, 1, 1, 1, 1, 1.2],
        rows: rows,
      );
    }

    final acc = <String, _BatAccum>{};
    
    // Initialize all batters in batting order, striker, non-striker
    final batterIds = <String>{
      ...inn.battingOrder,
      if (inn.strikerId != null && inn.strikerId!.isNotEmpty) inn.strikerId!,
      if (inn.nonStrikerId != null && inn.nonStrikerId!.isNotEmpty) inn.nonStrikerId!,
    };

    for (final id in batterIds) {
      acc[id] = _BatAccum();
    }

    final dismissals = <String, String>{};

    for (final ball in inn.balls) {
      if (ball.batsmanId.isNotEmpty) {
        final a = acc.putIfAbsent(ball.batsmanId, () => _BatAccum());
        if (ball.isLegalBall) {
          a.balls++;
        }
        // Runs off bat count for batsman on all balls (including no-balls)
        a.runs += ball.runs;
        if (ball.isBoundary && ball.runs == 4) a.fours++;
        if (ball.isSix) a.sixes++;
      }

      if (ball.isWicket && ball.dismissal != null) {
        final d = ball.dismissal!;
        final outId = d.batsmanId.isNotEmpty ? d.batsmanId : ball.batsmanId;
        if (outId.isNotEmpty) {
          acc.putIfAbsent(outId, () => _BatAccum());
          dismissals[outId] = _formatDismissal(st, d, ball.bowlerId, nameOf);
        }
      }
    }

    final entries = acc.entries.toList();
    final rows = entries.map((e) {
      final id = e.key;
      final a = e.value;
      String name = nameOf(id);
      if (id == inn.strikerId) {
        name += ' *';
      }

      String status = 'not out';
      if (dismissals.containsKey(id)) {
        status = dismissals[id]!;
      } else if (id == inn.strikerId || id == inn.nonStrikerId) {
        status = 'batting';
      } else if (a.balls == 0 && a.runs == 0) {
        status = 'yet to bat';
      }

      return <String>[
        name,
        status,
        '${a.runs}',
        '${a.balls}',
        '${a.fours}',
        '${a.sixes}',
        a.balls > 0 ? (a.runs * 100 / a.balls).toStringAsFixed(2) : '0.00',
      ];
    }).toList();

    return _tableCard(
      title: 'Batting',
      headers: const ['Batter', 'Status', 'R', 'B', '4s', '6s', 'SR'],
      widths: [2.5, 2.0, 1, 1, 1, 1, 1.2],
      rows: rows,
    );
  }

  Widget _bowlingCard(BuildContext context, SpectatorHomeState st, Innings inn,
      ScorerMatch match, LiveMatchData? liveData, String Function(String) nameOf) {
    // Self-contained scorecard from the RTDB payload for the current live
    // innings (see _battingCard).
    if (liveData != null && match.currentInningsData?.id == inn.id) {
      final rows = liveData.bowlingCard.map((b) {
        final name = b.name.isNotEmpty ? b.name : nameOf(b.playerId);
        return <String>[
          b.current ? '$name *' : name,
          b.oversLabel,
          '${b.maidens}',
          '${b.runs}',
          '${b.wickets}',
          b.economy.toStringAsFixed(2),
        ];
      }).toList();
      return _tableCard(
        title: 'Bowling',
        headers: const ['Bowler', 'O', 'M', 'R', 'W', 'Econ'],
        widths: [2.5, 1, 1, 1, 1, 1.2],
        rows: rows,
      );
    }

    final acc = <String, _BowlAccum>{};

    final bowlerIds = <String>{
      ...inn.bowlingOrder,
      if (inn.currentBowlerId != null && inn.currentBowlerId!.isNotEmpty) inn.currentBowlerId!,
    };

    for (final id in bowlerIds) {
      acc[id] = _BowlAccum();
    }

    for (final ball in inn.balls) {
      if (ball.bowlerId.isEmpty) continue;
      final b = acc.putIfAbsent(ball.bowlerId, () => _BowlAccum());
      
      // Runs charged to bowler (runs off bat + wide/no-ball extras, excluding byes/leg-byes)
      final runsCharged = ball.runs + (ball.extrasType == ExtrasType.wide || ball.extrasType == ExtrasType.noBall ? ball.extrasRuns : 0);
      b.runs += runsCharged;

      if (ball.isWicket && ball.dismissal?.type != DismissalType.runOut) {
        b.wickets++;
      }
      if (ball.isLegalBall) {
        b.legalBalls++;
      }
    }

    final rows = acc.entries.map((e) {
      final a = e.value;
      final balls = a.legalBalls;
      final overs = balls ~/ 6 + (balls % 6) / 10;
      final economy = balls > 0 ? (a.runs * 6) / balls : 0.0;
      String name = nameOf(e.key);
      if (e.key == inn.currentBowlerId) {
        name += ' *';
      }

      return <String>[
        name,
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
      widths: [2.5, 1, 1, 1, 1, 1.2],
      rows: rows,
    );
  }

  /// Over-by-over display: each over is its own column in a single horizontal
  /// row, headed by the over number and the bowler's name, with that over's
  /// balls laid out beneath.
  Widget _overByOverCard(
      Innings inn, String Function(String id) nameOf) {
    final byOver = <int, List<BallEvent>>{};
    for (final b in inn.balls) {
      byOver.putIfAbsent(b.overNumber, () => []).add(b);
    }
    final overNumbers = byOver.keys.toList()..sort();

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
          if (overNumbers.isEmpty)
            const Text('No deliveries yet.',
                style: TextStyle(color: Colors.white70, fontSize: 12))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final overNum in overNumbers)
                    _overColumn(overNum, byOver[overNum]!, nameOf),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _overColumn(int overNum, List<BallEvent> balls,
      String Function(String id) nameOf) {
    final bowlerId = balls.first.bowlerId;
    final bowlerName = bowlerId.isNotEmpty ? nameOf(bowlerId) : '—';
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Over',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
          const SizedBox(height: 1),
          Text('$overNum • $bowlerName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 9)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: balls.map((b) => _overBallChip(b)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _overBallChip(BallEvent b) {
    final color = b.isWicket
        ? Colors.redAccent
        : b.isSix
            ? Colors.amber
            : b.isBoundary
                ? Colors.greenAccent
                : !b.isLegalBall
                    ? Colors.orangeAccent
                    : Colors.white70;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(b.displayLabel,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
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
                  color: Colors.white,
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
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
          const Divider(color: Colors.white24, height: 8),
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
      ScorerMatch match, String teamId, String Function(String id) nameOf) {
    final xi = teamId == match.team1Id ? match.playingXI1 : match.playingXI2;
    final teamPlayers = st.playersForTeam(teamId);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradients[8],
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded,
                  color: AppColors.floodlightGoldLight, size: 18),
              const Gap(8),
              Text('${st.teamName(teamId)} — Playing XI',
                  style: AppTextStyles.titleSmall(Colors.white)
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
                        color: AppColors.floodlightGoldLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(nameOf(id),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13))),
                  Text(
                      _roleLabel(
                          teamPlayers.where((p) => p.id == id).firstOrNull),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 9)),
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

/// Resolves a player's real name for the spectator screen.
///
/// Prefers the self-contained RTDB live payload published by the scorer (which
/// carries every player id → name across all innings + both XIs), then the
/// per-squad maps, and finally falls back to the spectator's locally-hydrated
/// player list. This is what lets the scorecard and squads render actual names
/// even when the spectator device has not synced the scorer's players.
String resolvePlayerName(
    SpectatorHomeState st, LiveMatchData? liveData, String id) {
  if (liveData != null) {
    final fromPayload = liveData.players[id];
    if (fromPayload != null && fromPayload.isNotEmpty) {
      return fromPayload;
    }
    final fromSquad = liveData.squad1[id] ?? liveData.squad2[id];
    if (fromSquad != null && fromSquad.isNotEmpty && fromSquad != id) {
      return fromSquad;
    }
  }
  return st.playerName(id);
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
