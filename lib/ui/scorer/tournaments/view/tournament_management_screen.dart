import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_tournament.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
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
  late TextEditingController _venueController;
  late TextEditingController _customOversController;
  late TextEditingController _entryFeeController;
  late TextEditingController _winnerPrizeController;
  late TextEditingController _runnerUpPrizeController;
  late TextEditingController _securityCodeController;
  MatchFormat _selectedFormat = MatchFormat.t20;
  bool _nrrTiebreaker = true;
  int _numTeams = 4;
  List<String> _existingTeamIds = [];
  String? _existingSecurityCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _venueController = TextEditingController();
    _customOversController = TextEditingController(text: '20');
    _entryFeeController = TextEditingController();
    _winnerPrizeController = TextEditingController();
    _runnerUpPrizeController = TextEditingController();
    _securityCodeController = TextEditingController();

    if (widget.tournamentId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final tournament = await ref.read(scorerRepositoryProvider).getTournament(widget.tournamentId!);
    if (tournament != null) {
      setState(() {
        _nameController.text = tournament.name;
        _venueController.text = tournament.venue;
        _selectedFormat = tournament.format;
        _customOversController.text = tournament.customOvers.toString();
        _entryFeeController.text = tournament.entryFee != null ? tournament.entryFee!.toStringAsFixed(0) : '';
        _winnerPrizeController.text = tournament.winnerPrize != null ? tournament.winnerPrize!.toStringAsFixed(0) : '';
        _runnerUpPrizeController.text = tournament.runnerUpPrize != null ? tournament.runnerUpPrize!.toStringAsFixed(0) : '';
        _nrrTiebreaker = tournament.pointsRules.nrrAsTiebreaker;
        _numTeams = tournament.numTeams;
        _existingTeamIds = tournament.teamIds;
        _existingSecurityCode = tournament.securityCode;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _customOversController.dispose();
    _entryFeeController.dispose();
    _winnerPrizeController.dispose();
    _runnerUpPrizeController.dispose();
    _securityCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(scorerRepositoryProvider);
    final id = widget.tournamentId ?? 't_${DateTime.now().millisecondsSinceEpoch}';

    final enteredCode = _securityCodeController.text.trim();

    // Editing: the user must enter the original security code to proceed.
    if (widget.tournamentId != null) {
      if (enteredCode.isEmpty || enteredCode != (_existingSecurityCode ?? '')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect security code. Cannot edit this tournament.')),
        );
        return;
      }
    }

    if (widget.tournamentId == null && enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a security code for this tournament.')),
      );
      return;
    }

    final tournament = ScorerTournament(
      id: id,
      name: _nameController.text.trim(),
      ownerId: 'user_1',
      format: _selectedFormat,
      customOvers: int.tryParse(_customOversController.text) ?? 20,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 14)),
      venue: _venueController.text.trim(),
      numTeams: _numTeams,
      teamIds: _existingTeamIds,
      pointsRules: PointsRules(nrrAsTiebreaker: _nrrTiebreaker),
      entryFee: double.tryParse(_entryFeeController.text),
      winnerPrize: double.tryParse(_winnerPrizeController.text),
      runnerUpPrize: double.tryParse(_runnerUpPrizeController.text),
      securityCode: enteredCode,
    );

    await repo.saveTournament(tournament);
    ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament saved successfully!'), backgroundColor: AppColors.pitchGreen),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.tournamentId != null;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          isEdit ? 'Edit Tournament' : 'Create Tournament',
          style: AppTextStyles.headlineSmall(Colors.white),
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
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tournament Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.emoji_events, color: AppColors.floodlightGold),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const Gap(16),

                TextFormField(
                  controller: _venueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Venue / Stadium',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.location_on, color: AppColors.pitchGreenLight),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const Gap(16),

                DropdownButtonFormField<MatchFormat>(
                  initialValue: _selectedFormat,
                  dropdownColor: AppColors.darkSurface,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Match Format',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                  items: MatchFormat.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFormat = val);
                  },
                ),
                const Gap(16),

                TextFormField(
                  controller: _customOversController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Overs per Innings',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: OutlineInputBorder(),
                  ),
                ),
                const Gap(16),

                TextFormField(
                  controller: _securityCodeController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Security Code',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: isEdit
                        ? 'Enter the security code to edit'
                        : 'Set a code to protect this tournament',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.pitchGreenLight),
                    filled: true,
                    fillColor: AppColors.darkSurface,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Security code required' : null,
                ),
                const Gap(24),

                // Financials & Cash Prizes Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.floodlightGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.attach_money_rounded, color: AppColors.floodlightGold, size: 20),
                          Gap(6),
                          Text(
                            'Entry Fees & Cash Prizes',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const Gap(12),
                      TextFormField(
                        controller: _entryFeeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Team Entry Fee (e.g. 5000)',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: AppColors.pitchGreenLight),
                          filled: true,
                          fillColor: Color(0xFF2A2A2A),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const Gap(12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _winnerPrizeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Winner Cash Prize',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixText: '🏆 \$ ',
                                prefixStyle: TextStyle(color: AppColors.floodlightGold),
                                filled: true,
                                fillColor: Color(0xFF2A2A2A),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const Gap(10),
                          Expanded(
                            child: TextFormField(
                              controller: _runnerUpPrizeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Runner-Up Prize',
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixText: '🥈 \$ ',
                                prefixStyle: TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Color(0xFF2A2A2A),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                // Points Table & Rules
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Points Rules & Tiebreaker',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Gap(8),
                      const Text(
                        'Win: 2 pts | Tie/No Result: 1 pt | Loss: 0 pt',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Net Run Rate (NRR) as Tiebreaker', style: TextStyle(color: Colors.white, fontSize: 13)),
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
                    isEdit ? 'Update Tournament' : 'Save Tournament & Continue',
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
