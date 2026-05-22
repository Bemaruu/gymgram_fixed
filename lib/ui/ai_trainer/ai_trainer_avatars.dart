import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';

/// Catalogo de avatares prediseñados para el entrenador IA.
class AITrainerAvatars {
  static const List<String> ids = [
    'avatar_1',
    'avatar_2',
    'avatar_3',
    'avatar_4',
  ];

  static IconData iconFor(String id) {
    switch (id) {
      case 'avatar_1':
        return PhosphorIconsBold.barbell;
      case 'avatar_2':
        return PhosphorIconsBold.heartbeat;
      case 'avatar_3':
        return PhosphorIconsBold.flame;
      case 'avatar_4':
        return PhosphorIconsBold.lightning;
      default:
        return PhosphorIconsBold.user;
    }
  }

  static Color colorFor(String id) {
    switch (id) {
      case 'avatar_1':
        return AppColors.accentOrange;
      case 'avatar_2':
        return const Color(0xFFFF5252);
      case 'avatar_3':
        return const Color(0xFFFFB341);
      case 'avatar_4':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  static Widget circle({
    required String id,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [colorFor(id), colorFor(id).withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(iconFor(id), color: Colors.white, size: size * 0.5),
    );
  }
}
