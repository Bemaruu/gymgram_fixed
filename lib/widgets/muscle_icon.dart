import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/app_colors.dart';
import '../core/muscle_icon_map.dart';

class MuscleIcon extends StatelessWidget {
  final String exerciseOrMuscle;
  final double size;
  final Color? background;

  const MuscleIcon({
    super.key,
    required this.exerciseOrMuscle,
    this.size = 40,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final icon = MuscleIconMap.iconFor(exerciseOrMuscle);
    final bg = background ?? AppColors.ember50;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? PhosphorIconsDuotone.barbell,
        size: size * 0.55,
        color: AppColors.ember400,
      ),
    );
  }
}
