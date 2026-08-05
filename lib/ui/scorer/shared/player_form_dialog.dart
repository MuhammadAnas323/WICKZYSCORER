// lib/ui/scorer/shared/player_form_dialog.dart
// Reusable dialog to add or edit a scorer player.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.onSurfaceVariant;
    final surfaceColor = theme.colorScheme.surface;
    final fieldFillColor = theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant;

    final isEdit = widget.existingPlayer != null;
    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEdit ? l10n.translate('edit_player') : l10n.translate('add_player'),
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.translate('player_name'),
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldFillColor,
                border: const OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _jerseyController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Jersey #',
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldFillColor,
                border: const OutlineInputBorder(),
              ),
            ),
            const Gap(12),
            DropdownButtonFormField<PlayerRole>(
              value: _role,
              dropdownColor: surfaceColor,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: l10n.translate('role'),
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldFillColor,
                border: const OutlineInputBorder(),
              ),
              items: PlayerRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.name))).toList(),
              onChanged: (val) { if (val != null) setState(() => _role = val); },
            ),
            const Gap(12),
            DropdownButtonFormField<BattingStyle>(
              value: _battingStyle,
              dropdownColor: surfaceColor,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: l10n.translate('batting_style'),
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldFillColor,
                border: const OutlineInputBorder(),
              ),
              items: BattingStyle.values.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
              onChanged: (val) { if (val != null) setState(() => _battingStyle = val); },
            ),
            const Gap(12),
            DropdownButtonFormField<BowlingStyle>(
              value: _bowlingStyle,
              dropdownColor: surfaceColor,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: l10n.translate('bowling_style'),
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: fieldFillColor,
                border: const OutlineInputBorder(),
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
          child: Text(l10n.translate('cancel'), style: TextStyle(color: subTextColor)),
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
            Navigator.pop(context, player);
          },
          child: Text(isEdit ? l10n.translate('update') : l10n.translate('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
