import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';
import '../core/app_spacing.dart';
import '../core/app_radius.dart';

/// Toggle visual de tema. La persistencia debe manejarse externamente
/// (ej. SharedPreferences + ValueNotifier<ThemeMode> en main.dart).
class ThemeModeToggle extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeToggle({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.neutral100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(context, ThemeMode.light, PhosphorIconsRegular.sun, 'Claro'),
          _option(context, ThemeMode.system, PhosphorIconsRegular.deviceMobile, 'Auto'),
          _option(context, ThemeMode.dark, PhosphorIconsRegular.moon, 'Oscuro'),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, ThemeMode mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.auroraGradient : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.neutral0
                  : (isDark ? AppColors.darkTextSecondary : AppColors.neutral600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? AppColors.neutral0
                    : (isDark ? AppColors.darkTextSecondary : AppColors.neutral600),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
