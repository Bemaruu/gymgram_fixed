import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/app_shadows.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';

/// Sheet de celebración para cuando el usuario desbloquea una medalla.
///
/// Pensado para mostrarse vía `showModalBottomSheet` con
/// `backgroundColor: Colors.transparent` e `isScrollControlled: true`.
/// No está integrado en el flujo de medallas todavía — sólo es el
/// componente visual reutilizable.
class MedalCelebration extends StatelessWidget {
  final String medalAsset;
  final String medalName;
  final String? description;

  const MedalCelebration({
    super.key,
    required this.medalAsset,
    required this.medalName,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        gradient: AppColors.deepSkyGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral400.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '¡Logro desbloqueado!',
            style: AppTypography.overline.copyWith(color: AppColors.ember400),
          )
              .animate()
              .fadeIn(duration: 300.ms, delay: 200.ms)
              .slideY(begin: 0.5, end: 0),
          const SizedBox(height: AppSpacing.md),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: AppColors.medalGoldGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glow(AppColors.ember400),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1,
                    end: 1.05,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              Image.asset(medalAsset, width: 140, height: 140)
                  .animate()
                  .scaleXY(
                    begin: 0,
                    end: 1,
                    duration: 700.ms,
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .shimmer(
                    duration: 1500.ms,
                    color: AppColors.neutral0.withValues(alpha: 0.4),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            medalName,
            style: AppTypography.h2.copyWith(color: AppColors.neutral0),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideY(begin: 0.3, end: 0),
          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description!,
              style: AppTypography.body.copyWith(color: AppColors.neutral200),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
