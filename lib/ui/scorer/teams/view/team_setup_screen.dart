import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/scorer/scorer_team.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';
import 'package:sportyapp/ui/scorer/dashboard/viewmodel/scorer_dashboard_viewmodel.dart';

class TeamSetupScreen extends ConsumerStatefulWidget {
  final String? tournamentId;
  final String? teamId;

  const TeamSetupScreen({super.key, this.tournamentId, this.teamId});

  @override
  ConsumerState<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends ConsumerState<TeamSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortCodeController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  List<ScorerPlayer> _players = [];
  bool _isLoading = false;
  String? _resolvedTournamentId;

  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _resolvedTournamentId = widget.tournamentId;
    if (widget.teamId != null) _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    final repo = ref.read(scorerRepositoryProvider);
    final team = await repo.getTeam(widget.teamId!);
    if (team != null) {
      _nameController.text = team.name;
      _shortCodeController.text = team.shortCode;
      _ownerNameController.text = team.ownerName ?? '';
      _whatsappController.text = team.whatsappNumber ?? '';
      _resolvedTournamentId = team.tournamentId;
      _isPaid = team.isEntryFeePaid;
      final players = await repo.getPlayersByTeam(team.id);
      setState(() => _players = players);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortCodeController.dispose();
    _ownerNameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveTeam() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(scorerRepositoryProvider);
    final id = widget.teamId ?? 'team_${DateTime.now().millisecondsSinceEpoch}';

    final team = ScorerTeam(
      id: id,
      name: _nameController.text.trim(),
      shortCode: _shortCodeController.text.trim().toUpperCase(),
      tournamentId: _resolvedTournamentId ?? '',
      playerIds: _players.map((p) => p.id).toList(),
      isEntryFeePaid: _isPaid,
      ownerName: _ownerNameController.text.trim().isEmpty
          ? null
          : _ownerNameController.text.trim(),
      whatsappNumber: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
    );

    await repo.saveTeam(team);
    for (final player in _players) {
      await repo.savePlayer(player.copyWith(
          teamId: id, tournamentId: _resolvedTournamentId ?? ''));
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Team saved!'), backgroundColor: AppColors.pitchGreen),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if ((_resolvedTournamentId ?? '').isNotEmpty) {
      context.go('/scorer/tournaments/$_resolvedTournamentId');
    } else {
      context.pop();
    }

    // Refresh dashboards after leaving this screen; never blocks navigation.
    try {
      ref.read(scorerDashboardViewModelProvider.notifier).loadDashboard();
    } catch (_) {}
  }

  void _addPlayer() {
    showDialog(
      context: context,
      builder: (ctx) => _AddPlayerDialog(
        teamId: widget.teamId ?? 'temp',
        tournamentId: _resolvedTournamentId ?? '',
        onAdd: (player) {
          setState(() => _players.add(player));
        },
      ),
    );
  }

  void _removePlayer(ScorerPlayer player) {
    setState(() => _players.remove(player));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          widget.teamId == null ? 'Create Team' : 'Edit Team',
          style: AppTextStyles.headlineSmall(Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _saveTeam,
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.pitchGreenLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlayer,
        backgroundColor: AppColors.pitchGreen,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Player',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.pitchGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Team basic info
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Team Name',
                              labelStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.groups_rounded,
                                  color: AppColors.pitchGreenLight),
                              filled: true,
                              fillColor: AppColors.darkSurface,
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _shortCodeController,
                            style: const TextStyle(color: Colors.white),
                            maxLength: 4,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Code',
                              labelStyle: TextStyle(color: Colors.white70),
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.darkSurface,
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    TextFormField(
                      controller: _ownerNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Owner Name (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppColors.pitchGreenLight),
                        filled: true,
                        fillColor: AppColors.darkSurface,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Gap(12),
                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText:
                            'WhatsApp Number (Optional, e.g. +923001234567)',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: Icon(Icons.phone_android,
                            color: AppColors.pitchGreenLight),
                        filled: true,
                        fillColor: AppColors.darkSurface,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const Gap(14),
                    // Entry Fee Payment Status Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _isPaid
                                ? AppColors.pitchGreenLight.withOpacity(0.4)
                                : Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_isPaid ? Icons.check_circle : Icons.pending,
                                  color: _isPaid
                                      ? AppColors.pitchGreenLight
                                      : Colors.redAccent,
                                  size: 20),
                              const Gap(8),
                              Text(
                                'Tournament Entry Fee: ${_isPaid ? "PAID" : "UNPAID"}',
                                style: TextStyle(
                                    color: _isPaid
                                        ? AppColors.pitchGreenLight
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isPaid,
                            activeThumbColor: AppColors.pitchGreenLight,
                            onChanged: (val) => setState(() => _isPaid = val),
                          ),
                        ],
                      ),
                    ),
                    const Gap(20),

                    // Squad header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Squad (${_players.length} Players)',
                            style: AppTextStyles.titleLarge(Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pitchGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color:
                                    AppColors.pitchGreenLight.withOpacity(0.5)),
                          ),
                          child: const Text(
                            'Optional Squad Size',
                            style: TextStyle(
                                color: AppColors.pitchGreenLight,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),

                    if (_players.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.person_add_outlined,
                                size: 48, color: Colors.grey),
                            Gap(12),
                            Text(
                              'No players added yet',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                            Gap(4),
                            Text(
                              'Tap "Add Player" to build your squad',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      ...(_players.asMap().entries.map((entry) {
                        final i = entry.key;
                        final player = entry.value;
                        return _PlayerTile(
                          player: player,
                          index: i + 1,
                          onRemove: () => _removePlayer(player),
                          onEdit: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => _AddPlayerDialog(
                                teamId: widget.teamId ?? 'temp',
                                tournamentId: _resolvedTournamentId ?? '',
                                existingPlayer: player,
                                onAdd: (updated) {
                                  setState(() {
                                    _players[i] = updated;
                                  });
                                },
                              ),
                            );
                          },
                        );
                      })),

                    const Gap(100),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final ScorerPlayer player;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  const _PlayerTile(
      {required this.player,
      required this.index,
      required this.onRemove,
      required this.onEdit});

  Color _roleColor(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:
        return Colors.blueAccent;
      case PlayerRole.bowler:
        return Colors.redAccent;
      case PlayerRole.allRounder:
        return AppColors.pitchGreenLight;
      case PlayerRole.wicketKeeper:
        return Colors.orangeAccent;
    }
  }

  String _roleLabel(PlayerRole role) {
    switch (role) {
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

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(player.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Jersey number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleColor.withOpacity(0.15),
              border: Border.all(color: roleColor.withOpacity(0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${player.jerseyNumber ?? index}',
              style: TextStyle(
                  color: roleColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text(
                  '${player.battingStyle.name.toUpperCase()} • ${player.bowlingStyle.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_roleLabel(player.role),
                style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
          ),
          IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white54, size: 18),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 18),
              onPressed: onRemove),
        ],
      ),
    );
  }
}

class _AddPlayerDialog extends ConsumerStatefulWidget {
  final String teamId;
  final String tournamentId;
  final ScorerPlayer? existingPlayer;
  final ValueChanged<ScorerPlayer> onAdd;

  const _AddPlayerDialog({
    required this.teamId,
    required this.tournamentId,
    required this.onAdd,
    this.existingPlayer,
  });

  @override
  ConsumerState<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends ConsumerState<_AddPlayerDialog> {
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();
  PlayerRole _role = PlayerRole.batsman;
  BattingStyle _battingStyle = BattingStyle.rightHand;
  BowlingStyle _bowlingStyle = BowlingStyle.none;

  @override
  void initState() {
    super.initState();
    if (widget.existingPlayer != null) {
      final p = widget.existingPlayer!;
      _nameController.text = p.name;
      _jerseyController.text = '${p.jerseyNumber ?? ''}';
      _role = p.role;
      _battingStyle = p.battingStyle;
      _bowlingStyle = p.bowlingStyle;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPlayer != null;
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEdit ? 'Edit Player' : 'Add Player',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Player Name',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _jerseyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Jersey #',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            DropdownButtonFormField<PlayerRole>(
              value: _role,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: PlayerRole.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _role = val);
              },
            ),
            const Gap(12),
            DropdownButtonFormField<BattingStyle>(
              value: _battingStyle,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Batting Style',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: BattingStyle.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _battingStyle = val);
              },
            ),
            const Gap(12),
            DropdownButtonFormField<BowlingStyle>(
              value: _bowlingStyle,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bowling Style',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: BowlingStyle.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _bowlingStyle = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pitchGreen,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            final id = widget.existingPlayer?.id ??
                'p_${widget.teamId}_${_nameController.text.trim().replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
            final player = ScorerPlayer(
              id: id,
              name: _nameController.text.trim(),
              teamId: widget.teamId,
              tournamentId: widget.tournamentId,
              role: _role,
              battingStyle: _battingStyle,
              bowlingStyle: _bowlingStyle,
              jerseyNumber: int.tryParse(_jerseyController.text),
            );
            widget.onAdd(player);
            Navigator.pop(context);
          },
          child: Text(isEdit ? 'Update' : 'Add',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
