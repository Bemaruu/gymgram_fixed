import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';
import '../core/app_shadows.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';
import 'muscle_icon.dart';

class ExerciseCard extends StatelessWidget {
  final String name;
  final int? reps;
  final int? durationSeconds;
  final String gifUrl;
  final int? sets;
  final int? restSeconds;

  const ExerciseCard({
    super.key,
    required this.name,
    this.reps,
    this.durationSeconds,
    required this.gifUrl,
    this.sets,
    this.restSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.base,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: CachedNetworkImage(
                imageUrl: gifUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  height: 180,
                  color: AppColors.neutral100,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.sky400,
                    ),
                  ),
                ),
                errorWidget: (context, error, stackTrace) => Container(
                  height: 180,
                  color: AppColors.neutral100,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: AppColors.neutral400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                MuscleIcon(exerciseOrMuscle: name, size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.h3.copyWith(color: AppColors.sky900),
                  ),
                ),
              ],
            ),
            if (sets != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text(
                    'Series: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  Text(
                    '$sets',
                    style: AppTypography.numMd.copyWith(
                      color: AppColors.sky900,
                    ),
                  ),
                ],
              ),
            ],
            if (reps != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Text(
                    'Repeticiones: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  Text(
                    '$reps',
                    style: AppTypography.numMd.copyWith(
                      color: AppColors.sky900,
                    ),
                  ),
                ],
              ),
            ],
            if (durationSeconds != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Text(
                    'Duración: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  Text(
                    '${durationSeconds}s',
                    style: AppTypography.numMd.copyWith(
                      color: AppColors.sky900,
                    ),
                  ),
                ],
              ),
            ],
            if (restSeconds != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Text(
                    'Descanso: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  Text(
                    '${restSeconds}s',
                    style: AppTypography.numMd.copyWith(
                      color: AppColors.ember400,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
