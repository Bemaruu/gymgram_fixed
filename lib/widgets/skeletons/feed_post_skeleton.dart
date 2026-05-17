import 'package:flutter/material.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import 'skeleton_base.dart';

class FeedPostSkeleton extends StatelessWidget {
  const FeedPostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              SkeletonBase(width: 40, height: 40, radius: 999),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBase(width: 120, height: 12, radius: AppRadius.xs),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonBase(width: 80, height: 10, radius: AppRadius.xs),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AspectRatio(
            aspectRatio: 1,
            child: SkeletonBase(
              height: double.infinity,
              radius: AppRadius.base,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              SkeletonBase(width: 32, height: 32, radius: 999),
              SizedBox(width: AppSpacing.md),
              SkeletonBase(width: 32, height: 32, radius: 999),
              SizedBox(width: AppSpacing.md),
              SkeletonBase(width: 32, height: 32, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

class FeedPostSkeletonList extends StatelessWidget {
  final int count;
  const FeedPostSkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (_, __) => const FeedPostSkeleton(),
    );
  }
}
