// lib/ui/scorer/create_match/view/create_local_match_screen.dart
// "Create Local Match" screen — type team names manually OR pick from the
// dropdown of existing teams, then continue to the match-setup wizard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_match.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
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
  final _noteController = TextEditingController();

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
    _noteController.dispose();
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
    final l10n = AppLocalizations.of(context);
    final nameA = _teamAController.text.trim();
    final nameB = _teamBController.text.trim();
    if (nameA.isEmpty || nameB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_team_names_error')), backgroundColor: Colors.red),
      );
      return;
    }
    if (nameA.toLowerCase() == nameB.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('different_teams_error')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
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
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        status: MatchStatus.scheduled,
        playingXI1: const [],
        playingXI2: const [],
        currentInnings: 1,
      );
      await repo.saveMatch(match);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('match_created_success')),
          backgroundColor: AppColors.pitchGreen,
        ),
      );
      context.pushReplacement('/scorer/matches/${match.id}/squad');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _teamField({required String label, required TextEditingController controller}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onBackground),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.shield_outlined, color: AppColors.pitchGreenLight),
        suffixIcon: _allTeams.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface.withOpacity(0.7)),
                tooltip: l10n.translate('select_existing_team'),
                color: colorScheme.surface,
                onSelected: (name) => setState(() => controller.text = name),
                itemBuilder: (_) => _allTeams.map((t) => PopupMenuItem(
                  value: t.name,
                  child: Text(t.name, style: TextStyle(color: colorScheme.onSurface)),
                )).toList(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.translate('create_local_match'), style: AppTextStyles.headlineSmall(colorScheme.onBackground)),
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
                      Expanded(child: _teamField(label: l10n.translate('team_a'), controller: _teamAController)),
                      const Gap(12),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(l10n.translate('vs'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const Gap(12),
                      Expanded(child: _teamField(label: l10n.translate('team_b'), controller: _teamBController)),
                    ],
                  ),
                  const Gap(8),
                  Text(l10n.translate('create_match_hint'),
                      style: TextStyle(color: colorScheme.onBackground.withOpacity(0.54), fontSize: 12)),
                  const Gap(20),
                  TextFormField(
                    controller: _venueController,
                    style: TextStyle(color: colorScheme.onBackground),
                    decoration: InputDecoration(
                      labelText: l10n.translate('venue'),
                      labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on, color: AppColors.pitchGreenLight),
                    ),
                  ),
                  const Gap(20),
                  InkWell(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: AppColors.pitchGreenLight),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              _dateTime == null
                                  ? l10n.translate('optional_date_time')
                                  : _dateTime!.toLocal().toString().replaceRange(16, 19, ''),
                              style: TextStyle(
                                color: _dateTime == null ? colorScheme.onBackground.withOpacity(0.38) : colorScheme.onBackground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_dateTime != null)
                            IconButton(
                              icon: Icon(Icons.close, color: colorScheme.onBackground.withOpacity(0.38), size: 18),
                              onPressed: () => setState(() => _dateTime = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(20),

                  TextFormField(
                    controller: _oversController,
                    style: TextStyle(color: colorScheme.onBackground),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.translate('overs'),
                      labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const Gap(20),
                  TextFormField(
                    controller: _noteController,
                    style: TextStyle(color: colorScheme.onBackground),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.translate('note_optional'),
                      labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.7)),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor ?? colorScheme.surfaceVariant,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.pitchGreenLight),
                    ),
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
                    label: Text(_isSaving ? l10n.translate('creating') : l10n.translate('create_local_match'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _isSaving ? null : _createMatch,
                  ),
                ],
              ),
            ),
    );
  }
}