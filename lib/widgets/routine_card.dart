import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';
import '../core/app_shadows.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';
import 'muscle_icon.dart';

class RoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final bool isOwner;
  final VoidCallback? onTap;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.isOwner,
    this.onTap,
  });

  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  String _formatGoal(String? g) {
    switch ((g ?? '').toUpperCase()) {
      case 'LOSE_WEIGHT':
        return 'Perder peso';
      case 'GAIN_MUSCLE':
        return 'Ganar músculo';
      case 'MAINTAIN':
        return 'Mantener';
      default:
        return 'Sin objetivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = routine['title'] as String? ?? 'Rutina';
    final goal = _formatGoal(routine['goal'] as String?);
    final dayIndex = routine['day_of_week'] as int?;
    final dayLabel = (dayIndex != null && dayIndex >= 0 && dayIndex < 7)
        ? _dayNames[dayIndex]
        : null;
    final exercises =
        (routine['routine_exercises'] as List?)?.length ?? 0;
    final copies = (routine['copies_count'] as int?) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.neutral0,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.base,
        ),
        child: Row(
          children: [
            MuscleIcon(exerciseOrMuscle: title, size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.sky900,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (dayLabel != null) dayLabel,
                      goal,
                      '$exercises ejercicios',
                    ].join(' · '),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (copies >= 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.sky400,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$copies copias',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.sky400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isOwner)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.sky400,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.copy_rounded,
                      color: AppColors.neutral0,
                      size: 14,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Copiar',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
