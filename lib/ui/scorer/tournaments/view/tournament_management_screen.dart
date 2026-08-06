import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class TournamentManagementScreen extends ConsumerStatefulWidget {
  final String? tournamentId;
  const TournamentManagementScreen({super.key, this.tournamentId});

  @override
  ConsumerState<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends ConsumerState<TournamentManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _organizerController;
  late TextEditingController _venueController;
  late TextEditingController _customOversController;
  late TextEditingController _entryFeeController;
  late TextEditingController _winnerPrizeController;
  late TextEditingController _runnerUpPrizeController;
  late TextEditingController _securityCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _rulesController;
  late TextEditingController _requirementsController;
  // Default tournament format (internal), UI field removed.
  final MatchFormat _defaultFormat = MatchFormat.t20;
  bool _nrrTiebreaker = true;
  int _numTeams = 4;
  List<String> _existingTeamIds = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _organizerController = TextEditingController();
    _venueController = TextEditingController();
    _customOversController = TextEditingController(text: '20');
    _entryFeeController = TextEditingController();
    _winnerPrizeController = TextEditingController();
    _runnerUpPrizeController = TextEditingController();
    _securityCodeController = TextEditingController();
    _descriptionController = TextEditingController();
    _rulesController = TextEditingController();
    _requirementsController = TextEditingController();

    if (widget.tournamentId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final tournament = await ref.read(scorerRepositoryProvider).getTournament(widget.tournamentId!);
    if (tournament != null) {
      setState(() {
        _nameController.text = tournament.name;
        _organizerController.text = tournament.organizer;
        _venueController.text = tournament.venue;

        _customOversController.text = tournament.customOvers.toString();
        _entryFeeController.text = tournament.entryFee != null ? tournament.entryFee!.toStringAsFixed(0) : '';
        _winnerPrizeController.text = tournament.winnerPrize != null ? tournament.winnerPrize!.toStringAsFixed(0) : '';
        _runnerUpPrizeController.text = tournament.runnerUpPrize != null ? tournament.runnerUpPrize!.toStringAsFixed(0) : '';
        _descriptionController.text = tournament.description ?? '';
        _rulesController.text = tournament.tournamentRules ?? '';
        _requirementsController.text = tournament.tournamentRequirements ?? '';
        _nrrTiebreaker = tournament.pointsRules.nrrAsTiebreaker;
        _numTeams = tournament.numTeams;
        _existingTeamIds = tournament.teamIds;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    _venueController.dispose();
    _customOversController.dispose();
    _entryFeeController.dispose();
    _winnerPrizeController.dispose();
    _runnerUpPrizeController.dispose();
    _securityCodeController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  /// Converts free-form multiline text into a numbered points list
  /// (e.g. "1- Rule one\n2- Rule two\n3- Rule three"). Any existing
  /// "N-" / "N." prefixes are stripped first so numbering is always clean.
  String _formatAsPoints(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final cleaned =
          lines[i].replaceFirst(RegExp(r'^\d+\s*[-.]\s*'), '');
      buffer.writeln('${i + 1}- $cleaned');
    }
    return buffer.toString().trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final repo = ref.read(scorerRepositoryProvider);
      final user = ref.read(currentUserProvider);
      final id = widget.tournamentId ?? 't_${DateTime.now().millisecondsSinceEpoch}';

      final tournament = ScorerTournament(
        id: id,
        name: _nameController.text.trim(),
        ownerId: user?.id ?? 'user_1',
        createdBy: user?.id ?? '',
        organizer: _organizerController.text.trim(),
        format: _defaultFormat,
        customOvers: int.tryParse(_customOversController.text) ?? 20,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 14)),
        venue: _venueController.text.trim(),
        numTeams: _numTeams,
        teamIds: _existingTeamIds,
        pointsRules: PointsRules(nrrAsTiebreaker: _nrrTiebreaker),
        entryFee: _entryFeeController.text.isNotEmpty ? double.tryParse(_entryFeeController.text) : null,
        winnerPrize: _winnerPrizeController.text.isNotEmpty ? double.tryParse(_winnerPrizeController.text) : null,
        runnerUpPrize: _runnerUpPrizeController.text.isNotEmpty ? double.tryParse(_runnerUpPrizeController.text) : null,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text.trim() : null,
        tournamentRules: _rulesController.text.isNotEmpty ? _formatAsPoints(_rulesController.text) : null,
        tournamentRequirements: _requirementsController.text.isNotEmpty ? _formatAsPoints(_requirementsController.text) : null,
      );

      await repo.saveTournament(tournament);

      // Refresh dashboards after navigation so it never blocks leaving the form.
      try {
        ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
      } catch (_) {}

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('save')), backgroundColor: AppColors.pitchGreen),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tournamentId != null;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onBackground;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;
    final fieldFillColor = theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(
          isEdit ? l10n.translate('edit_tournament') : l10n.translate('create_tournament'),
          style: AppTextStyles.headlineSmall(textColor),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: l10n.translate('tournament_name'),
                    labelStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(Icons.emoji_events, color: AppColors.floodlightGold),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? l10n.translate('required') : null,
                ),
                const Gap(16),

                TextFormField(
                  controller: _organizerController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: l10n.translate('organizer'),
                    labelStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.pitchGreenLight),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(16),

                TextFormField(
                  controller: _venueController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: l10n.translate('venue'),
                    labelStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(Icons.location_on, color: AppColors.pitchGreenLight),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? l10n.translate('required') : null,
                ),
                const Gap(16),

                // Match Format field removed as per requirements.
                const Gap(16),

                TextFormField(
                  controller: _customOversController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: l10n.translate('overs_per_innings'),
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(16),

                // Financials & Cash Prizes Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.floodlightGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.attach_money_rounded, color: AppColors.floodlightGold, size: 20),
                          const Gap(6),
                          Text(
                            l10n.translate('cash_prizes'),
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _entryFeeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: l10n.translate('tournament_entry_fee'),
                          labelStyle: TextStyle(color: subTextColor),
                          prefixText: 'PKR ',
                          prefixStyle: const TextStyle(color: AppColors.pitchGreenLight),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _winnerPrizeController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: l10n.translate('winner_prize'),
                                labelStyle: TextStyle(color: subTextColor),
                                prefixText: '🏆 PKR ',
                                prefixStyle: const TextStyle(color: AppColors.floodlightGold),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: TextFormField(
                              controller: _runnerUpPrizeController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: l10n.translate('runner_up_prize'),
                                labelStyle: TextStyle(color: subTextColor),
                                prefixText: '🥈 PKR ',
                                prefixStyle: TextStyle(color: subTextColor),
                                filled: true,
                                fillColor: fieldFillColor,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(color: textColor),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.translate('description') == 'description' ? 'Description' : l10n.translate('description'),
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(20),

                // Rules
                TextFormField(
                  controller: _rulesController,
                  style: TextStyle(color: textColor),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Tournament Rules',
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(20),

                // Requirements
                TextFormField(
                  controller: _requirementsController,
                  style: TextStyle(color: textColor),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Tournament Requirements',
                    labelStyle: TextStyle(color: subTextColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const Gap(20),

                // Points Table & Rules
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('points_rules'),
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Gap(8),
                      Text(
                        'Win: 2 pts | Tie/No Result: 1 pt | Loss: 0 pt',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.translate('nrr_tiebreaker'), style: TextStyle(color: textColor, fontSize: 13)),
                        value: _nrrTiebreaker,
                        activeThumbColor: AppColors.pitchGreenLight,
                        onChanged: (val) => setState(() => _nrrTiebreaker = val),
                      ),
                    ],
                  ),
                ),
                const Gap(32),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pitchGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEdit ? l10n.translate('update') : l10n.translate('save'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
