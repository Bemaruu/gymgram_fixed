import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import 'skeleton_base.dart';

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SkeletonBase(width: 88, height: 88, radius: 999),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBase(width: 160, height: 22, radius: AppRadius.xs),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBase(width: 120, height: 14, radius: AppRadius.xs),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _StatBlock(),
              _StatBlock(),
              _StatBlock(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              9,
              (_) => const SkeletonBase(
                height: double.infinity,
                radius: AppRadius.md,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SkeletonBase(width: 40, height: 18, radius: AppRadius.xs),
        SizedBox(height: AppSpacing.xs),
        SkeletonBase(width: 60, height: 12, radius: AppRadius.xs),
      ],
    );
  }
}
