import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/models/scorer/innings.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/data/repositories/scorer_live_match_repository.dart';
import 'package:sportyapp/ui/scorer/shared/player_form_dialog.dart';


/// Full match-setup wizard — pick teams, playing XI, toss, opening batsmen, opening bowler
class MatchSetupScreen extends ConsumerStatefulWidget {
  final String? matchId; // if editing existing match

  const MatchSetupScreen({super.key, this.matchId});

  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  int _step = 0; // 0=match info, 1=toss, 2=opening players

  // Step 0 – Match info
  String? _team1Id;
  String? _team2Id;
  String _venue = '';
  DateTime? _dateTime; // optional
  int _overs = 20;
  MatchFormat _format = MatchFormat.t20;
  List<ScorerTeam> _allTeams = [];

  // Step 1 – Toss
  String? _tossWinnerId;
  TossDecision _tossDecision = TossDecision.bat;

  // Step 2 – Playing XI & Openers
  List<ScorerPlayer> _team1Players = [];
  List<ScorerPlayer> _team2Players = [];
  final Set<String> _playingXI1 = {};
  final Set<String> _playingXI2 = {};
  String? _openingStrikerId;
  String? _openingNonStrikerId;
  String? _openingBowlerId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final teams = await repo.getAllTeams();
    if (!mounted) return;
    setState(() {
      _allTeams = teams;
      _isLoading = false;
    });
  }

  Future<void> _loadPlayers() async {
    if (_team1Id == null || _team2Id == null) return;
    final repo = ref.read(scorerRepositoryProvider);
    final [p1, p2] = await Future.wait([
      repo.getPlayersByTeam(_team1Id!),
      repo.getPlayersByTeam(_team2Id!),
    ]);
    setState(() {
      _team1Players = p1;
      _team2Players = p2;
      _playingXI1.addAll(p1.map((p) => p.id));
      _playingXI2.addAll(p2.map((p) => p.id));
    });
  }

  Future<void> _addPlayerToTeam(String teamId) async {
    final repo = ref.read(scorerRepositoryProvider);
    final team = await repo.getTeam(teamId);
    await showDialog(
      context: context,
      builder: (ctx) => PlayerFormDialog(
        teamId: teamId,
        tournamentId: team?.tournamentId ?? '',
        onSave: (player) async {
          await repo.savePlayer(player);
          if (!mounted) return;
          if (teamId == _team1Id) {
            setState(() {
              _team1Players.add(player);
              _playingXI1.add(player.id);
            });
          } else if (teamId == _team2Id) {
            setState(() {
              _team2Players.add(player);
              _playingXI2.add(player.id);
            });
          }
        },
      ),
    );
  }

  Future<void> _exchangePlayers() async {
    if (_team1Id == null || _team2Id == null) return;
    final repo = ref.read(scorerRepositoryProvider);
    final player1 = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => _PlayerPickDialog(
        title: 'Select player from ${_teamName(_team1Id)}',
        players: _team1Players,
      ),
    );
    if (player1 == null || !mounted) return;
    final player2 = await showDialog<ScorerPlayer>(
      context: context,
      builder: (ctx) => _PlayerPickDialog(
        title: 'Select player from ${_teamName(_team2Id)}',
        players: _team2Players,
      ),
    );
    if (player2 == null || !mounted) return;

    // Swap team membership + playing XI membership
    final t1 = await repo.getTeam(_team1Id!);
    final t2 = await repo.getTeam(_team2Id!);
    await repo.savePlayer(player1.copyWith(
      teamId: _team2Id!,
      tournamentId: t2?.tournamentId ?? '',
    ));
    await repo.savePlayer(player2.copyWith(
      teamId: _team1Id!,
      tournamentId: t1?.tournamentId ?? '',
    ));

    // Swap team playerIds
    if (t1 != null) {
      await repo.saveTeam(t1.copyWith(playerIds: t1.playerIds.map((id) => id == player1.id ? player2.id : id).toList()));
    }
    if (t2 != null) {
      await repo.saveTeam(t2.copyWith(playerIds: t2.playerIds.map((id) => id == player2.id ? player1.id : id).toList()));
    }

    // Swap XI lists
    setState(() {
      if (_playingXI1.contains(player1.id)) {
        _playingXI1.remove(player1.id);
        _playingXI1.add(player2.id);
      }
      if (_playingXI2.contains(player2.id)) {
        _playingXI2.remove(player2.id);
        _playingXI2.add(player1.id);
      }
    });
    await _loadPlayers();
  }

  Future<void> _pickMatchDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? now),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _nextStep() {
    if (_step == 0) {
      if (_team1Id == null || _team2Id == null || _team1Id == _team2Id || _venue.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all match info fields'), backgroundColor: Colors.red),
        );
        return;
      }
      _loadPlayers();
    }
    if (_step == 1 && _tossWinnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the toss winner'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _step++);
  }

  void _prevStep() {
    setState(() => _step--);
  }

  String _teamName(String? id) {
    if (id == null) return 'Team';
    return _allTeams.firstWhere((t) => t.id == id, orElse: () => ScorerTeam(id: id, name: id, shortCode: id, tournamentId: '', playerIds: [])).name;
  }

  List<ScorerPlayer> _battingPlayers() {
    // The batting team is determined by the toss
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId == _team1Id ? _team1Players : _team2Players;
  }

  List<ScorerPlayer> _bowlingPlayers() {
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId == _team1Id ? _team2Players : _team1Players;
  }

  String _battingTeamId() {
    final battingTeamId = (_tossDecision == TossDecision.bat) ? _tossWinnerId : (_tossWinnerId == _team1Id ? _team2Id : _team1Id);
    return battingTeamId ?? _team1Id!;
  }

  String _bowlingTeamId() {
    final bat = _battingTeamId();
    return bat == _team1Id ? _team2Id! : _team1Id!;
  }

  Future<void> _startMatch() async {
    if (_openingStrikerId == null || _openingNonStrikerId == null || _openingBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select opening batsmen and bowler'), backgroundColor: Colors.red),
      );
      return;
    }

    final repo = ref.read(scorerRepositoryProvider);
    final matchId = 'm_${DateTime.now().millisecondsSinceEpoch}';
    final battingTeamId = _battingTeamId();
    final bowlingTeamId = _bowlingTeamId();

    final inn1 = Innings(
      id: 'inn_1_$matchId',
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

    final match = ScorerMatch(
      id: matchId,
      tournamentId: 't_custom',
      team1Id: _team1Id!,
      team2Id: _team2Id!,
      venue: _venue,
      dateTime: _dateTime ?? DateTime.now(),
      format: _format,
      overs: _overs,
      status: MatchStatus.inProgress,
      tossWinnerId: _tossWinnerId,
      tossDecision: _tossDecision,
      playingXI1: _playingXI1.toList(),
      playingXI2: _playingXI2.toList(),
      openingStrikerId: _openingStrikerId,
      openingNonStrikerId: _openingNonStrikerId,
      openingBowlerId: _openingBowlerId,
      innings1: inn1,
      currentInnings: 1,
    );

    await repo.saveMatch(match);
    ref.read(scorerLiveMatchRepositoryProvider).setActiveMatch(match);

    if (mounted) context.pushReplacement('/scorer/live-scoring');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _prevStep)
            : const BackButton(color: Colors.white),
        title: Text(['Match Info', 'Toss', 'Opening Players'][_step], style: AppTextStyles.headlineSmall(Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.white12,
            color: AppColors.pitchGreen,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : switch (_step) {
              0 => _buildStep0(),
              1 => _buildStep1(),
              _ => _buildStep2(),
            },
    );
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('Select Teams'),
          const Gap(12),
          Row(
            children: [
              Expanded(child: _teamPicker('Team 1', _team1Id, (val) => setState(() => _team1Id = val))),
              const Gap(12),
              const Text('vs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
              const Gap(12),
              Expanded(child: _teamPicker('Team 2', _team2Id, (val) => setState(() => _team2Id = val))),
            ],
          ),
          const Gap(20),
          _sectionLabel('Venue'),
          const Gap(8),
          TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => setState(() => _venue = val),
            decoration: const InputDecoration(
              hintText: 'Enter venue name',
              hintStyle: TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.darkSurface,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on, color: AppColors.pitchGreenLight),
            ),
          ),
          const Gap(20),
          _sectionLabel('Match Time (Optional)'),
          const Gap(8),
          InkWell(
            onTap: _pickMatchDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.pitchGreenLight),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      _dateTime == null
                          ? 'Set a date & time (optional)'
                          : _dateTime!.toLocal().toString().replaceRange(16, 19, ''),
                      style: TextStyle(
                        color: _dateTime == null ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_dateTime != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _dateTime = null),
                    ),
                ],
              ),
            ),
          ),
          const Gap(20),
          _sectionLabel('Format & Overs'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MatchFormat>(
                  value: _format,
                  dropdownColor: AppColors.darkSurface,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                  items: MatchFormat.values.map((f) => DropdownMenuItem(value: f, child: Text(f.name.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() {
                      _format = val;
                      _overs = val == MatchFormat.t20 ? 20 : val == MatchFormat.odi ? 50 : 5;
                    });
                  },
                ),
              ),
              const Gap(12),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  controller: TextEditingController(text: '$_overs'),
                  onChanged: (val) => setState(() => _overs = int.tryParse(val) ?? _overs),
                  decoration: const InputDecoration(
                    labelText: 'Overs',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const Gap(32),
          _nextButton('Continue to Toss →'),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final t1Name = _teamName(_team1Id);
    final t2Name = _teamName(_team2Id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Who won the toss?', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Gap(16),
          _tossTeamButton(t1Name, _team1Id!),
          const Gap(12),
          _tossTeamButton(t2Name, _team2Id!),
          const Gap(32),
          if (_tossWinnerId != null) ...[
            const Text('Toss winner elected to:', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Gap(12),
            Row(
              children: [
                Expanded(child: _tossDecisionButton('Bat First', TossDecision.bat, Icons.sports_cricket)),
                const Gap(12),
                Expanded(child: _tossDecisionButton('Bowl First', TossDecision.bowl, Icons.catching_pokemon)),
              ],
            ),
            const Gap(32),
            _nextButton('Set Opening Players →'),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final battingPlayers = _battingPlayers();
    final bowlingPlayers = _bowlingPlayers();
    final battingTeamName = _teamName(_battingTeamId());
    final bowlingTeamName = _teamName(_bowlingTeamId());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionLabel('$battingTeamName — Opening Batsmen'),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: AppColors.pitchGreenLight, size: 20),
                tooltip: 'Add Player to ${_teamName(_battingTeamId())}',
                onPressed: () => _addPlayerToTeam(_battingTeamId()),
              ),
            ],
          ),
          const Gap(8),
          ...battingPlayers.take(11).map((p) => _playerSelectorTile(
            player: p,
            isStriker: _openingStrikerId == p.id,
            isNonStriker: _openingNonStrikerId == p.id,
            onTapStriker: () => setState(() => _openingStrikerId = p.id),
            onTapNonStriker: () => setState(() => _openingNonStrikerId = p.id),
          )),
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: _sectionLabel('$bowlingTeamName — Opening Bowler'),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt_1, color: Colors.redAccent, size: 20),
                tooltip: 'Add Player to ${_teamName(_bowlingTeamId())}',
                onPressed: () => _addPlayerToTeam(_bowlingTeamId()),
              ),
            ],
          ),
          const Gap(8),
          ...bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).take(6).map((p) => _bowlerSelectorTile(
            player: p,
            isSelected: _openingBowlerId == p.id,
            onTap: () => setState(() => _openingBowlerId = p.id),
          )),
          if (bowlingPlayers.where((p) => p.bowlingStyle != BowlingStyle.none).isEmpty)
            ...bowlingPlayers.take(6).map((p) => _bowlerSelectorTile(
              player: p,
              isSelected: _openingBowlerId == p.id,
              onTap: () => setState(() => _openingBowlerId = p.id),
            )),
          const Gap(16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('Exchange Player between Teams', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _exchangePlayers,
          ),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.sports_score_rounded, size: 24),
            label: const Text('🔴  Start Live Scoring', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            onPressed: _startMatch,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5));

  Widget _teamPicker(String label, String? selected, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: selected,
      dropdownColor: AppColors.darkSurface,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: const OutlineInputBorder(),
      ),
      hint: const Text('Select team', style: TextStyle(color: Colors.white38)),
      items: _allTeams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _tossTeamButton(String name, String teamId) {
    final isSelected = _tossWinnerId == teamId;
    return GestureDetector(
      onTap: () => setState(() => _tossWinnerId = teamId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pitchGreen.withOpacity(0.2) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.pitchGreenLight : Colors.white24, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle_rounded : Icons.circle_outlined, color: isSelected ? AppColors.pitchGreenLight : Colors.white54),
            const Gap(12),
            Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _tossDecisionButton(String label, TossDecision decision, IconData icon) {
    final isSelected = _tossDecision == decision;
    return GestureDetector(
      onTap: () => setState(() => _tossDecision = decision),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.floodlightGold.withOpacity(0.15) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.floodlightGold : Colors.white24, width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.floodlightGold : Colors.white54, size: 28),
            const Gap(6),
            Text(label, style: TextStyle(color: isSelected ? AppColors.floodlightGold : Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

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

  Widget _nextButton(String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: _nextStep,
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}

class _PlayerPickDialog extends StatelessWidget {
  final String title;
  final List<ScorerPlayer> players;

  const _PlayerPickDialog({required this.title, required this.players});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: players.isEmpty
            ? const Center(child: Text('No players', style: TextStyle(color: Colors.white54)))
            : ListView.separated(
                itemCount: players.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (ctx, i) {
                  final p = players[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.pitchGreen.withOpacity(0.2),
                      child: Text('${p.jerseyNumber ?? '?'}', style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 12)),
                    ),
                    title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text(p.role.name, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
