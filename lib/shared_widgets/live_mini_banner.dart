import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/extensions/int_extensions.dart';
import 'package:sportyapp/ui/streaming/go_live/viewmodel/go_live_viewmodel.dart';

class LiveMiniBanner extends ConsumerWidget {
  const LiveMiniBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goLiveStateProvider);

    if (!state.isLive || !state.isMinimized) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        ref.read(goLiveViewModelProvider).restoreStream();
        context.push('/go-live');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border(top: BorderSide(color: AppColors.liveRed.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.liveRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('LIVE', style: AppTextStyles.labelSmall(Colors.white)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.title.isEmpty ? 'My Stream' : state.title,
                style: AppTextStyles.bodySmall(Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              state.durationSeconds.toHMS,
              style: AppTextStyles.labelSmall(Colors.white70)
                  .copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ref.read(goLiveViewModelProvider).endStream(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.liveRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('End', style: AppTextStyles.labelSmall(AppColors.liveRed)
                    .copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
