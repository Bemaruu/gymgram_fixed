import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';
import '../core/app_shadows.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';

class PersonalRoutineCard extends StatelessWidget {
  final List<Map<String, dynamic>> routines;
  final bool isOwner;
  final String? ownerUsername;
  final VoidCallback onTap;

  const PersonalRoutineCard({
    super.key,
    required this.routines,
    required this.isOwner,
    required this.onTap,
    this.ownerUsername,
  });

  @override
  Widget build(BuildContext context) {
    final daysWithExercises = routines
        .where((r) => ((r['routine_exercises'] as List?)?.isNotEmpty ?? false))
        .map((r) => r['day_of_week'])
        .toSet()
        .length;
    final totalExercises = routines.fold<int>(
      0,
      (sum, r) => sum + ((r['routine_exercises'] as List?)?.length ?? 0),
    );
    final totalCopies = routines.fold<int>(
      0,
      (sum, r) => sum + ((r['copies_count'] as int?) ?? 0),
    );

    final title = isOwner
        ? 'Mi Rutina Personal'
        : 'Rutina de ${ownerUsername != null ? '@$ownerUsername' : 'usuario'}';

    final subtitle = daysWithExercises == 0
        ? 'Sin ejercicios aún'
        : '$daysWithExercises ${daysWithExercises == 1 ? 'día' : 'días'} · $totalExercises ejercicios';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.neutral0,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.sky50.withValues(alpha: 0.4),
              AppColors.ember50.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.base,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.auroraGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.glow(AppColors.sky400),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.neutral0,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.sky900,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                  if (totalCopies >= 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.ember400,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$totalCopies ${totalCopies == 1 ? "copia" : "copias"}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ember400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    isOwner
                        ? 'Toca para ver y editar la semana'
                        : 'Toca para ver y copiar la semana',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.sky700,
            ),
          ],
        ),
      ),
    );
  }
}
