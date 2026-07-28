import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/tournament_model.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

final _ptProvider = FutureProvider.family<TournamentModel?, String>(
  (ref, id) => ref.read(tournamentRepositoryProvider).getTournamentById(id));

class PointsTableScreen extends ConsumerWidget {
  final String tournamentId;
  const PointsTableScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_ptProvider(tournamentId));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Points Table',
        style: AppTextStyles.headlineSmall(cs.onBackground))),
      body: async.when(
        loading: () => const MatchListSkeleton(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (t) {
          if (t == null) return const ErrorState(message: 'Tournament not found');
          final entries = t.pointsTable;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.name, style: AppTextStyles.headlineSmall(cs.onBackground)),
              const SizedBox(height: 16),
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
                    ...['M','W','L','Pts','NRR'].map((h) => Expanded(
                      child: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center))),
                  ],
                ),
              ),
              ...entries.asMap().entries.map((e) {
                final entry = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  color: e.key.isOdd ? cs.surfaceVariant.withOpacity(0.3) : cs.surface,
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text(entry.position.toString(),
                        style: AppTextStyles.labelMedium(cs.onSurfaceVariant))),
                      Expanded(flex: 3, child: Row(children: [
                        Text(entry.teamFlag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(entry.teamShortName, style: AppTextStyles.labelMedium(cs.onBackground)
                          .copyWith(fontWeight: FontWeight.w700)),
                      ])),
                      ...[
                        entry.matches.toString(), entry.wins.toString(), entry.losses.toString(),
                        entry.points.toString(),
                        (entry.netRunRate >= 0 ? '+' : '') + entry.netRunRate.toStringAsFixed(3),
                      ].map((v) => Expanded(child: Text(v,
                        style: AppTextStyles.labelMedium(cs.onBackground)
                          .copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center))),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
