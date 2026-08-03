// lib/ui/scorer/create_match/view/create_local_match_screen.dart
// "Create Local Match" screen — type team names manually OR pick from the
// dropdown of existing teams, then continue to the match-setup wizard.

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

class CreateLocalMatchScreen extends ConsumerStatefulWidget {
  const CreateLocalMatchScreen({super.key});

  @override
  ConsumerState<CreateLocalMatchScreen> createState() => _CreateLocalMatchScreenState();
}

class _CreateLocalMatchScreenState extends ConsumerState<CreateLocalMatchScreen> {
  final _teamAController = TextEditingController();
  final _teamBController = TextEditingController();
  final _venueController = TextEditingController();
  final _oversController = TextEditingController(text: '20');

  MatchFormat _format = MatchFormat.t20;
  DateTime? _dateTime;
  List<ScorerTeam> _allTeams = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    _venueController.dispose();
    _oversController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    final repo = ref.read(scorerRepositoryProvider);
    final teams = await repo.getAllTeams();
    if (!mounted) return;
    setState(() {
      _allTeams = teams;
      _isLoading = false;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: now,
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

  Future<String> _resolveTeam(String name, int serial) async {
    final repo = ref.read(scorerRepositoryProvider);
    final match = _allTeams.where((t) =>
        t.name.trim().toLowerCase() == name.trim().toLowerCase()).firstOrNull;
    if (match != null) return match.id;

    final trimmed = name.trim();
    final id = 'team_local_${DateTime.now().millisecondsSinceEpoch}_$serial';
    final team = ScorerTeam(
      id: id,
      name: trimmed,
      shortCode: trimmed.length >= 3 ? trimmed.substring(0, 3).toUpperCase() : trimmed.toUpperCase(),
      tournamentId: 't_custom',
      playerIds: const [],
    );
    await repo.saveTeam(team);
    if (mounted) setState(() => _allTeams = List.of(_allTeams)..add(team));
    return id;
  }

  Future<void> _createMatch() async {
    final nameA = _teamAController.text.trim();
    final nameB = _teamBController.text.trim();
    if (nameA.isEmpty || nameB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both team names'), backgroundColor: Colors.red),
      );
      return;
    }
    if (nameA.toLowerCase() == nameB.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teams must be different'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(scorerRepositoryProvider);
    final teamAId = await _resolveTeam(nameA, 1);
    final teamBId = await _resolveTeam(nameB, 2);

    final match = ScorerMatch(
      id: 'm_local_${DateTime.now().millisecondsSinceEpoch}',
      tournamentId: 't_custom',
      team1Id: teamAId,
      team2Id: teamBId,
      venue: _venueController.text.trim(),
      dateTime: _dateTime ?? DateTime.now(),
      format: _format,
      overs: int.tryParse(_oversController.text) ?? 20,
      status: MatchStatus.scheduled,
      playingXI1: const [],
      playingXI2: const [],
      currentInnings: 1,
    );
    await repo.saveMatch(match);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Match created — set up the squads'),
        backgroundColor: AppColors.pitchGreen,
      ),
    );
    context.pushReplacement('/scorer/matches/${match.id}/squad');
  }

  Widget _teamField({required String label, required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.shield_outlined, color: AppColors.pitchGreenLight),
        suffixIcon: _allTeams.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                tooltip: 'Select from existing teams',
                color: AppColors.darkSurface,
                onSelected: (name) => setState(() => controller.text = name),
                itemBuilder: (_) => _allTeams.map((t) => PopupMenuItem(
                  value: t.name,
                  child: Text(t.name, style: const TextStyle(color: Colors.white)),
                )).toList(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Create Local Match', style: AppTextStyles.headlineSmall(Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _teamField(label: 'Team A', controller: _teamAController)),
                      const Gap(12),
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text('vs', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const Gap(12),
                      Expanded(child: _teamField(label: 'Team B', controller: _teamBController)),
                    ],
                  ),
                  const Gap(8),
                  const Text('Enter team names manually, or tap the dropdown to pick an existing team.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Gap(20),
                  TextFormField(
                    controller: _venueController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      labelStyle: TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: AppColors.darkSurface,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on, color: AppColors.pitchGreenLight),
                    ),
                  ),
                  const Gap(20),
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
                          const Icon(Icons.schedule, color: AppColors.pitchGreenLight),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              _dateTime == null
                                  ? 'Set date & time (optional)'
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
                          items: MatchFormat.values.map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.name.toUpperCase()),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() {
                              _format = val;
                              _oversController.text = val == MatchFormat.t20
                                  ? '20'
                                  : val == MatchFormat.odi ? '50' : '5';
                            });
                          },
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: TextFormField(
                          controller: _oversController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.liveRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sports_score_rounded, size: 24),
                    label: Text(_isSaving ? 'Creating…' : 'Create Local Match',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _isSaving ? null : _createMatch,
                  ),
                ],
              ),
            ),
    );
  }
}