import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/app_colors.dart';

/// Icono animado para indicadores de racha / streak.
///
/// Aplica un halo con [AppColors.streakFireGradient] que late suavemente
/// detrás del icono de llama.
class StreakFire extends StatelessWidget {
  final double size;

  const StreakFire({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.8,
          height: size * 1.8,
          decoration: const BoxDecoration(
            gradient: AppColors.streakFireGradient,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 0.85,
              end: 1.0,
              duration: 900.ms,
              curve: Curves.easeInOut,
            ),
        Icon(
          PhosphorIconsFill.flame,
          color: AppColors.neutral0,
          size: size,
        ),
      ],
    );
  }
}
