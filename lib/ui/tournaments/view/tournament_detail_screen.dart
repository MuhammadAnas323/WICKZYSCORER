import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

final _tournamentDetailProvider = FutureProvider.family<TournamentModel?, String>(
  (ref, id) => ref.read(tournamentRepositoryProvider).getTournamentById(id));

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const TournamentDetailScreen({super.key, required this.tournamentId});
  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_tournamentDetailProvider(widget.tournamentId));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const MatchListSkeleton()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: e.toString())),
      data: (tournament) {
        if (tournament == null) return Scaffold(appBar: AppBar(),
          body: const ErrorState(message: 'Tournament not found'));

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 160,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(gradient: AppColors.heroCardGradient),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏆', style: const TextStyle(fontSize: 40)),
                            Text(tournament.name,
                              style: AppTextStyles.headlineMedium(Colors.white)),
                            Text(tournament.host,
                              style: AppTextStyles.bodyMedium(Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.floodlightGold,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [Tab(text: 'Overview'), Tab(text: 'Points Table')],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(tournament: tournament),
                _PointsTableTab(tournament: tournament),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final TournamentModel tournament;
  const _OverviewTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('About', style: AppTextStyles.titleLarge(cs.onBackground)),
        const SizedBox(height: 8),
        Text(tournament.description, style: AppTextStyles.bodyMedium(cs.onSurfaceVariant)),
        const SizedBox(height: 24),
        Text('Participating Teams', style: AppTextStyles.titleLarge(cs.onBackground)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: tournament.pointsTable.map((e) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text('${e.teamFlag} ${e.teamShortName}',
              style: AppTextStyles.labelMedium(cs.onBackground)),
          )).toList(),
        ),
      ],
    );
  }
}

class _PointsTableTab extends StatelessWidget {
  final TournamentModel tournament;
  const _PointsTableTab({required this.tournament});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = tournament.pointsTable;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.pitchGreen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMD)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white70, fontSize: 11))),
              const Expanded(flex: 3, child: Text('Team', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
              ...['M','W','L','NR','Pts','NRR'].map((h) => Expanded(
                child: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center))),
            ],
          ),
        ),
        ...entries.asMap().entries.map((e) {
          final entry = e.value;
          final isOdd = e.key.isOdd;
          Color? rowColor;
          if (entry.isQualified) rowColor = AppColors.pitchGreen.withOpacity(0.08);
          if (entry.isEliminated) rowColor = AppColors.ballRed.withOpacity(0.05);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            color: rowColor ?? (isOdd ? cs.surfaceVariant.withOpacity(0.3) : cs.surface),
            child: Row(
              children: [
                SizedBox(width: 24,
                  child: Text(entry.position.toString(),
                    style: AppTextStyles.labelMedium(cs.onSurfaceVariant))),
                Expanded(flex: 3,
                  child: Row(children: [
                    Text(entry.teamFlag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(entry.teamShortName,
                      style: AppTextStyles.labelMedium(cs.onBackground)
                        .copyWith(fontWeight: FontWeight.w700)),
                    if (entry.isQualified)
                      const Padding(padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle, size: 12, color: AppColors.pitchGreen)),
                    if (entry.isEliminated)
                      const Padding(padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.cancel, size: 12, color: AppColors.ballRed)),
                  ]),
                ),
                ...[
                  entry.matches.toString(), entry.wins.toString(), entry.losses.toString(),
                  entry.noResult.toString(), entry.points.toString(),
                  (entry.netRunRate >= 0 ? '+' : '') + entry.netRunRate.toStringAsFixed(3),
                ].map((v) => Expanded(child: Text(v,
                  style: AppTextStyles.labelMedium(
                    v.startsWith('+') ? AppColors.pitchGreen :
                    v.startsWith('-') ? AppColors.ballRed : cs.onBackground)
                  .copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center))),
              ],
            ),
          );
        }),
      ],
    );
  }
}
