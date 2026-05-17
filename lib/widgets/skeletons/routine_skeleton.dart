import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_shadows.dart';
import '../../core/app_spacing.dart';
import 'skeleton_base.dart';

class RoutineSkeleton extends StatelessWidget {
  const RoutineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
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
          SkeletonBase(width: 80, height: 80, radius: AppRadius.md),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBase(width: 160, height: 16, radius: AppRadius.xs),
                SizedBox(height: AppSpacing.sm),
                SkeletonBase(width: 120, height: 12, radius: AppRadius.xs),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    SkeletonBase(width: 50, height: 10, radius: AppRadius.xs),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBase(width: 50, height: 10, radius: AppRadius.xs),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoutineSkeletonList extends StatelessWidget {
  final int count;
  const RoutineSkeletonList({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (_) => const RoutineSkeleton()),
    );
  }
}
