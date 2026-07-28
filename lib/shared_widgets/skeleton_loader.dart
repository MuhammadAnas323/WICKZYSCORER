import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/constants/app_constants.dart';

/// Generic shimmer skeleton box.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppConstants.radiusMD,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.shimmerBase : AppColors.shimmerBaseLight,
      highlightColor:
          isDark ? AppColors.shimmerHighlight : AppColors.shimmerHighlightLight,
      child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton for a match card (horizontal).
class MatchCardSkeleton extends StatelessWidget {
  const MatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SkeletonBox(width: 80, height: 12, radius: 4),
            Spacer(),
            SkeletonBox(width: 48, height: 22, radius: 100),
          ]),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SkeletonBox(width: 44, height: 44, radius: 22),
                SizedBox(height: 6),
                SkeletonBox(width: 60, height: 10, radius: 4),
                SizedBox(height: 4),
                SkeletonBox(width: 80, height: 16, radius: 4),
              ]),
              SkeletonBox(width: 24, height: 14, radius: 4),
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SkeletonBox(width: 44, height: 44, radius: 22),
                SizedBox(height: 6),
                SkeletonBox(width: 60, height: 10, radius: 4),
                SizedBox(height: 4),
                SkeletonBox(width: 80, height: 16, radius: 4),
              ]),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 10, radius: 4),
        ],
      ),
    );
  }
}

/// Skeleton list of [count] MatchCardSkeleton items.
class MatchListSkeleton extends StatelessWidget {
  final int count;
  const MatchListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (_, __) => const MatchCardSkeleton(),
    );
  }
}
