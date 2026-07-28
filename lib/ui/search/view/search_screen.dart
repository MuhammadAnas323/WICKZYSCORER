import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/ui/search/viewmodel/search_viewmodel.dart';
import 'package:sportyapp/shared_widgets/match_card.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchViewModelProvider.notifier).search(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search matches, players, teams...',
            hintStyle: AppTextStyles.bodyMedium(cs.onSurfaceVariant),
            border: InputBorder.none,
            filled: false,
          ),
          style: AppTextStyles.bodyMedium(cs.onSurface),
        ),
        actions: [
          if (state.query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchViewModelProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: state.query.isEmpty
        ? const EmptyState(
            emoji: '🔍',
            title: 'Search Cricket',
            subtitle: 'Search for matches, players, teams, or tournaments.',
          )
        : state.isLoading
            ? const MatchListSkeleton(count: 3)
            : _buildResults(context, state),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    final cs = Theme.of(context).colorScheme;
    final total = state.matches.length + state.players.length +
      state.teams.length + state.tournaments.length;

    if (total == 0) {
      return EmptyState(
        emoji: '👀',
        title: 'No results for "${state.query}"',
        subtitle: 'Try a different search term.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.matches.isNotEmpty) ...
          [Text('Matches', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          ...state.matches.map((m) => MatchCard(
            match: m, onTap: () => context.push('/match/${m.id}'))),
          const SizedBox(height: 16)],
        if (state.teams.isNotEmpty) ...
          [Text('Teams', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          ...state.teams.map((t) => ListTile(
            leading: Text(t.flagEmoji, style: const TextStyle(fontSize: 24)),
            title: Text(t.name, style: AppTextStyles.bodyMedium(cs.onSurface)
              .copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('Rank #${t.ranking}',
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
            onTap: () => context.push('/team/${t.id}'),
            trailing: const Icon(Icons.chevron_right),
          )),
          const SizedBox(height: 16)],
        if (state.players.isNotEmpty) ...
          [Text('Players', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          ...state.players.map((p) => ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.1),
              child: Text(p.teamFlag, style: const TextStyle(fontSize: 16)),
            ),
            title: Text(p.name, style: AppTextStyles.bodyMedium(cs.onSurface)
              .copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('${p.teamName} • ${p.role.name}',
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
            onTap: () => context.push('/player/${p.id}'),
            trailing: const Icon(Icons.chevron_right),
          )),
          const SizedBox(height: 16)],
        if (state.tournaments.isNotEmpty) ...
          [Text('Tournaments', style: AppTextStyles.titleLarge(cs.onSurface)),
          const SizedBox(height: 8),
          ...state.tournaments.map((t) => ListTile(
            leading: const Text('🏆', style: TextStyle(fontSize: 24)),
            title: Text(t.name, style: AppTextStyles.bodyMedium(cs.onSurface)
              .copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(t.host,
              style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
            onTap: () => context.push('/tournaments/${t.id}'),
            trailing: const Icon(Icons.chevron_right),
          ))],
      ],
    );
  }
}
