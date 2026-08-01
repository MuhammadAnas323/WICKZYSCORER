// lib/ui/scorer/shared/player_form_dialog.dart
// Reusable dialog to add or edit a scorer player.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/data/models/scorer/scorer_player.dart';

class PlayerFormDialog extends StatefulWidget {
  final String teamId;
  final String tournamentId;
  final ScorerPlayer? existingPlayer;
  final ValueChanged<ScorerPlayer> onSave;

  const PlayerFormDialog({
    super.key,
    required this.teamId,
    required this.tournamentId,
    required this.onSave,
    this.existingPlayer,
  });

  @override
  State<PlayerFormDialog> createState() => _PlayerFormDialogState();
}

class _PlayerFormDialogState extends State<PlayerFormDialog> {
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();
  PlayerRole _role = PlayerRole.batsman;
  BattingStyle _battingStyle = BattingStyle.rightHand;
  BowlingStyle _bowlingStyle = BowlingStyle.none;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlayer;
    if (p != null) {
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              initialValue: _role,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: PlayerRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
              onChanged: (val) { if (val != null) setState(() => _role = val); },
            ),
            const Gap(12),
            DropdownButtonFormField<BattingStyle>(
              initialValue: _battingStyle,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Batting Style',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: BattingStyle.values.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
              onChanged: (val) { if (val != null) setState(() => _battingStyle = val); },
            ),
            const Gap(12),
            DropdownButtonFormField<BowlingStyle>(
              initialValue: _bowlingStyle,
              dropdownColor: AppColors.darkSurface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bowling Style',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
              items: BowlingStyle.values.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
              onChanged: (val) { if (val != null) setState(() => _bowlingStyle = val); },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            widget.onSave(player);
            Navigator.pop(context);
          },
          child: Text(isEdit ? 'Update' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
