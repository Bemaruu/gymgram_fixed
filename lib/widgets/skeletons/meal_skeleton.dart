import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_shadows.dart';
import '../../core/app_spacing.dart';
import 'skeleton_base.dart';

class MealSkeleton extends StatelessWidget {
  const MealSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.base,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.base,
      ),
      child: Row(
        children: const [
          SkeletonBase(width: 44, height: 44, radius: 999),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBase(width: 140, height: 14, radius: AppRadius.xs),
                SizedBox(height: AppSpacing.sm),
                SkeletonBase(width: 90, height: 12, radius: AppRadius.xs),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          SkeletonBase(width: 60, height: 18, radius: AppRadius.xs),
        ],
      ),
    );
  }
}

class MealSkeletonList extends StatelessWidget {
  final int count;
  const MealSkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (_) => const MealSkeleton()),
    );
  }
}
