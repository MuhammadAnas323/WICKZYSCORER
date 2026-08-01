// lib/ui/scorer/start_scoring/view/toss_screen.dart
// Toss + opening batsmen/bowler, then start the live scoring draft.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';

class TossScreen extends ConsumerStatefulWidget {
  final String matchId;

  const TossScreen({super.key, required this.matchId});

  @override
  ConsumerState<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends ConsumerState<TossScreen> {
  ScorerMatch? _match;
  List<ScorerPlayer> _team1Players = [];
  List<ScorerPlayer> _team2Players = [];
  bool _loading = true;
  bool _starting = false;

  String? _tossWinnerId;
  TossDecision _tossDecision = TossDecision.bat;
  String? _openingStrikerId;
  String? _openingNonStrikerId;
  String? _openingBowlerId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    final match = await repo.findMatchById(widget.matchId);
    if (match == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(match.team1Id),
      repo.getPlayersByTeam(match.team2Id),
    ]);
    if (!mounted) return;
    setState(() {
      _match = match;
      _team1Players = p1;
      _team2Players = p2;
      _loading = false;
    });
  }

  String? get _battingTeamId {
    if (_tossWinnerId == null) return null;
    if (_tossDecision == TossDecision.bat) return _tossWinnerId;
    return _tossWinnerId == _match?.team1Id ? _match?.team2Id : _match?.team1Id;
  }

  String? get _bowlingTeamId {
    final bat = _battingTeamId;
    if (bat == null) return null;
    return bat == _match?.team1Id ? _match?.team2Id : _match?.team1Id;
  }

  List<ScorerPlayer> _battingPlayers() =>
      _battingTeamId == _match?.team1Id ? _team1Players : _team2Players;

  List<ScorerPlayer> _bowlingPlayers() =>
      _bowlingTeamId == _match?.team1Id ? _team1Players : _team2Players;

  Future<void> _startScoring() async {
    final match = _match;
    if (match == null) return;
    final battingTeamId = _battingTeamId;
    final bowlingTeamId = _bowlingTeamId;
    if (battingTeamId == null ||
        bowlingTeamId == null ||
        _openingStrikerId == null ||
        _openingNonStrikerId == null ||
        _openingBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete the toss, openers and bowler'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _starting = true);
    final repo = ref.read(scorerRepositoryProvider);

    final inn1 = Innings(
      id: 'inn_1_${match.id}',
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      inningsNumber: 1,
      balls: const [],
      battingOrder: [_openingStrikerId!, _openingNonStrikerId!],
      bowlingOrder: [_openingBowlerId!],
      isComplete: false,
      strikerId: _openingStrikerId,
      nonStrikerId: _openingNonStrikerId,
      currentBowlerId: _openingBowlerId,
    );

    final started = match.copyWith(
      tossWinnerId: _tossWinnerId,
      tossDecision: _tossDecision,
      openingStrikerId: _openingStrikerId,
      openingNonStrikerId: _openingNonStrikerId,
      openingBowlerId: _openingBowlerId,
      playingXI1: _team1Players.map((p) => p.id).toList(),
      playingXI2: _team2Players.map((p) => p.id).toList(),
      status: MatchStatus.inProgress,
      innings1: inn1,
      currentInnings: 1,
    );

    await repo.saveMatch(started);
    ref.read(scorerLiveMatchRepositoryProvider).setActiveMatch(started);
    if (!mounted) return;
    context.pushReplacement('/scorer/live-scoring');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Toss & Openers',
            style: AppTextStyles.titleMedium(Colors.white)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _match == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Match not found', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const Gap(16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.pitchGreen),
                        onPressed: () => context.pop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tossPicker(),
          const Gap(28),
          _openingPlayersPicker(),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _starting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sports_score_rounded, size: 24),
            label: Text(_starting ? 'Starting…' : 'Start Live Scoring', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _starting ? null : _startScoring,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _tossPicker() {
    final match = _match!;
    final t1 = _teamName(match.team1Id);
    final t2 = _teamName(match.team2Id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Who won the toss?', style: TextStyle(color: Colors.white70, fontSize: 16)),
        const Gap(12),
        Row(
          children: [
            Expanded(child: _selectCard(t1, _tossWinnerId == match.team1Id, () => setState(() => _tossWinnerId = match.team1Id))),
            const Gap(12),
            Expanded(child: _selectCard(t2, _tossWinnerId == match.team2Id, () => setState(() => _tossWinnerId = match.team2Id))),
          ],
        ),
        if (_tossWinnerId != null) ...[
          const Gap(20),
          const Text('Elected to:', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Gap(12),
          Row(
            children: [
              Expanded(child: _decisionCard('Bat First', TossDecision.bat, Icons.sports_cricket)),
              const Gap(12),
              Expanded(child: _decisionCard('Bowl First', TossDecision.bowl, Icons.catching_pokemon)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _selectCard(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pitchGreen.withOpacity(0.2) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.pitchGreenLight : Colors.white24, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected ? AppColors.pitchGreenLight : Colors.white54, size: 24),
            const Gap(8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _decisionCard(String label, TossDecision decision, IconData icon) {
    final isSelected = _tossDecision == decision;
    return GestureDetector(
      onTap: () => setState(() => _tossDecision = decision),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.floodlightGold.withOpacity(0.15) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.floodlightGold : Colors.white24, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.floodlightGold : Colors.white54, size: 26),
            const Gap(6),
            Text(label, style: TextStyle(color: isSelected ? AppColors.floodlightGold : Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _openingPlayersPicker() {
    final battingPlayers = _battingPlayers();
    final bowlingPlayers = _bowlingPlayers();
    final battingName = _teamName(_battingTeamId);
    final bowlingName = _teamName(_bowlingTeamId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$battingName — Opening Batsmen', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const Gap(8),
        ...battingPlayers.take(11).map((p) => _playerSelectorTile(
          player: p,
          isStriker: _openingStrikerId == p.id,
          isNonStriker: _openingNonStrikerId == p.id,
          onTapStriker: () => setState(() => _openingStrikerId = p.id),
          onTapNonStriker: () => setState(() => _openingNonStrikerId = p.id),
        )),
        const Gap(20),
        Text('$bowlingName — Opening Bowler', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const Gap(8),
        ...bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).take(6).map((p) => _bowlerSelectorTile(
          player: p,
          isSelected: _openingBowlerId == p.id,
          onTap: () => setState(() => _openingBowlerId = p.id),
        )),
      ],
    );
  }

  String _teamName(String? id) => id ?? 'Team';

  Widget _playerSelectorTile({
    required ScorerPlayer player,
    required bool isStriker,
    required bool isNonStriker,
    required VoidCallback onTapStriker,
    required VoidCallback onTapNonStriker,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isStriker || isNonStriker) ? AppColors.pitchGreen.withOpacity(0.1) : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isStriker || isNonStriker) ? AppColors.pitchGreenLight.withOpacity(0.5) : Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          _pillButton('Striker', isStriker, onTapStriker, Colors.blueAccent),
          const Gap(8),
          _pillButton('Non-Striker', isNonStriker, onTapNonStriker, AppColors.pitchGreenLight),
        ],
      ),
    );
  }

  Widget _bowlerSelectorTile({required ScorerPlayer player, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.1) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Colors.redAccent : Colors.white54),
            const Gap(12),
            Expanded(child: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            Text(player.bowlingStyle.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, bool isActive, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: isActive ? color : Colors.white54, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
