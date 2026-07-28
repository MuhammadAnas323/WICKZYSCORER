import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/match_model.dart';
import 'package:sportyapp/features/admin/viewmodel/create_match_viewmodel.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _seriesNameController;
  late TextEditingController _seriesIdController;
  late TextEditingController _venueController;
  late TextEditingController _cityController;
  late TextEditingController _umpiresController;
  late TextEditingController _totalOversController;

  MatchFormat _format = MatchFormat.t20;
  String? _teamAId;
  String? _teamBId;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String? _tossWinner;
  String? _tossDecision;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _seriesNameController = TextEditingController();
    _seriesIdController = TextEditingController();
    _venueController = TextEditingController();
    _cityController = TextEditingController();
    _umpiresController = TextEditingController();
    _totalOversController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _seriesNameController.dispose();
    _seriesIdController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _umpiresController.dispose();
    _totalOversController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledAt),
      );
      if (time != null) {
        setState(() {
          _scheduledAt = DateTime(
            picked.year, picked.month, picked.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createMatchViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    if (state.isSuccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match Created')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: AppColors.pitchGreen),
                const SizedBox(height: 24),
                Text('Match Created Successfully!',
                  style: AppTextStyles.titleLarge(cs.onSurface)),
                const SizedBox(height: 8),
                Text('Match ID: ${state.matchId}',
                  style: AppTextStyles.bodySmall(cs.onSurfaceVariant)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(createMatchViewModelProvider.notifier).reset();
                    context.pop();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Another'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    ref.read(createMatchViewModelProvider.notifier).reset();
                    context.go('/admin');
                  },
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create New Match')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Match Details', style: AppTextStyles.titleLarge(cs.onSurface)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Match Title',
                hintText: 'e.g. Pakistan vs India, 3rd T20I',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _seriesNameController,
                    decoration: const InputDecoration(
                      labelText: 'Series Name',
                      hintText: 'Asia Cup 2026',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _seriesIdController,
                    decoration: const InputDecoration(
                      labelText: 'Series ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<MatchFormat>(
              value: _format,
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
              ),
              items: MatchFormat.values.map((f) => DropdownMenuItem(
                value: f,
                child: Text(f.name.toUpperCase()),
              )).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _format = v;
                    if (v == MatchFormat.t20) _totalOversController.text = '20';
                    else if (v == MatchFormat.odi) _totalOversController.text = '50';
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Teams
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _teamAId,
                    decoration: const InputDecoration(
                      labelText: 'Team A',
                      border: OutlineInputBorder(),
                    ),
                    items: state.teams.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.flagEmoji} ${t.shortName}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _teamAId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('vs'),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _teamBId,
                    decoration: const InputDecoration(
                      labelText: 'Team B',
                      border: OutlineInputBorder(),
                    ),
                    items: state.teams.where((t) => t.id != _teamAId).map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.flagEmoji} ${t.shortName}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _teamBId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Venue
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _umpiresController,
              decoration: const InputDecoration(
                labelText: 'Umpires',
                hintText: 'e.g. Aleem Dar, Kumar Dharmasena',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalOversController,
                    decoration: const InputDecoration(
                      labelText: 'Total Overs',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Scheduled At',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        '${_scheduledAt.day}/${_scheduledAt.month}/${_scheduledAt.year} ${_scheduledAt.hour}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.bodyMedium(cs.onSurface),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toss
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tossWinner,
                    decoration: const InputDecoration(
                      labelText: 'Toss Winner',
                      border: OutlineInputBorder(),
                    ),
                    items: [_teamAId, _teamBId]
                        .whereType<String>()
                        .map((id) {
                          final team = state.teams.where((t) => t.id == id).firstOrNull;
                          return DropdownMenuItem(
                            value: id,
                            child: Text(team != null ? '${team.flagEmoji} ${team.shortName}' : id),
                          );
                        })
                        .toList(),
                    onChanged: (v) => setState(() => _tossWinner = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tossDecision,
                    decoration: const InputDecoration(
                      labelText: 'Decision',
                      border: OutlineInputBorder(),
                    ),
                    items: ['bat', 'bowl'].map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.toUpperCase()),
                    )).toList(),
                    onChanged: (v) => setState(() => _tossDecision = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        ref.read(createMatchViewModelProvider.notifier).createMatch(
                          title: _titleController.text,
                          seriesName: _seriesNameController.text,
                          seriesId: _seriesIdController.text,
                          format: _format,
                          teamAId: _teamAId!,
                          teamBId: _teamBId!,
                          scheduledAt: _scheduledAt,
                          venue: _venueController.text,
                          city: _cityController.text,
                          umpires: _umpiresController.text,
                          totalOvers: int.tryParse(_totalOversController.text),
                          tossWinner: _tossWinner,
                          tossDecision: _tossDecision,
                        );
                      }
                    },
              child: state.isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Match & Start Live'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(state.error!, style: AppTextStyles.bodySmall(AppColors.ballRed)),
            ],
          ],
        ),
      ),
    );
  }
}
