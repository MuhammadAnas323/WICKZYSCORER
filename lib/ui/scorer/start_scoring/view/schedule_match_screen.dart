// lib/ui/scorer/start_scoring/view/schedule_match_screen.dart
// Schedule an upcoming match for a tournament (teams, venue, date/time).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class ScheduleMatchScreen extends ConsumerStatefulWidget {
  final String? tournamentId;

  const ScheduleMatchScreen({super.key, this.tournamentId});

  @override
  ConsumerState<ScheduleMatchScreen> createState() =>
      _ScheduleMatchScreenState();
}

class _ScheduleMatchScreenState extends ConsumerState<ScheduleMatchScreen> {
  ScorerTournament? _tournament;
  List<ScorerTeam> _teams = [];
  bool _loading = true;
  bool _saving = false;

  String? _team1Id;
  String? _team2Id;
  String _venue = '';
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(scorerRepositoryProvider);
    if (widget.tournamentId != null) {
      final t = await repo.getTournament(widget.tournamentId!);
      final teams = await repo.getTeamsByTournament(widget.tournamentId!);
      if (!mounted) return;
      setState(() {
        _tournament = t;
        _teams = teams;
        _loading = false;
      });
    } else {
      final tournaments = await repo.getTournaments();
      if (!mounted) return;
      if (tournaments.isNotEmpty) {
        final t = tournaments.first;
        final teams = await repo.getTeamsByTournament(t.id);
        if (!mounted) return;
        setState(() {
          _tournament = t;
          _teams = teams;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _schedule() async {
    if (_team1Id == null || _team2Id == null || _team1Id == _team2Id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select two different teams'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_tournament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tournament selected'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(scorerRepositoryProvider);
    final t = _tournament!;
    final match = ScorerMatch(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      tournamentId: t.id,
      team1Id: _team1Id!,
      team2Id: _team2Id!,
      venue: _venue,
      dateTime: _dateTime,
      format: t.format,
      overs: t.format == MatchFormat.t20 ? 20 : t.format == MatchFormat.odi ? 50 : t.customOvers,
      status: MatchStatus.upcoming,
      playingXI1: const [],
      playingXI2: const [],
      currentInnings: 1,
    );

    await repo.saveMatch(match);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match scheduled'), backgroundColor: AppColors.pitchGreen),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Schedule Match',
            style: AppTextStyles.titleMedium(Colors.white)
                .copyWith(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : _tournament == null
              ? _noTournament()
              : _buildForm(),
    );
  }

  Widget _noTournament() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.charcoal400),
          const Gap(16),
          const Text(
            'No tournaments available',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Gap(6),
          const Text(
            'Create a tournament first.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Gap(24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => context.push('/scorer/tournaments/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final teams = _teams;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.pitchGreen.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.pitchGreenLight, size: 22),
                const Gap(10),
                Expanded(
                  child: Text(
                    _tournament!.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _tournament!.format.name.toUpperCase(),
                  style: const TextStyle(color: AppColors.pitchGreenLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Gap(24),
          _label('Team 1'),
          const Gap(8),
          _teamDropdown('Select Team 1', _team1Id, (val) => setState(() => _team1Id = val), teams),
          const Gap(16),
          _label('Team 2'),
          const Gap(8),
          _teamDropdown('Select Team 2', _team2Id, (val) => setState(() => _team2Id = val), teams),
          const Gap(24),
          _label('Venue'),
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
          const Gap(24),
          _label('Date & Time'),
          const Gap(8),
          InkWell(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.pitchGreenLight),
                  const Gap(12),
                  Text(
                    _dateTime.toLocal().toString().replaceRange(16, 19, ''),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Gap(32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 24),
            label: Text(_saving ? 'Scheduling…' : 'Schedule Match', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _saving ? null : _schedule,
          ),
          const Gap(40),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
      );

  Widget _teamDropdown(
    String hint,
    String? selected,
    ValueChanged<String?> onChanged,
    List<ScorerTeam> teams,
  ) {
    return DropdownButtonFormField<String>(
      value: selected,
      dropdownColor: AppColors.darkSurface,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: const OutlineInputBorder(),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      items: teams
          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
