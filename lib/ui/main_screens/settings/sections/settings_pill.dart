import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

enum SettingsPillState { hidden, warning, locked, unlimited }

class SettingsPill extends StatelessWidget {
  final SettingsPillState state;
  final String label;

  const SettingsPill({
    super.key,
    required this.state,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (state == SettingsPillState.hidden) return const SizedBox.shrink();

    Color bg;
    Color fg;
    IconData? icon;
    switch (state) {
      case SettingsPillState.warning:
        bg = AppColors.settingsWarning.withValues(alpha: 0.18);
        fg = AppColors.settingsWarning;
        break;
      case SettingsPillState.locked:
        bg = AppColors.settingsDanger.withValues(alpha: 0.18);
        fg = AppColors.settingsDanger;
        icon = Icons.lock_outline;
        break;
      case SettingsPillState.unlimited:
        bg = AppColors.accentOrange.withValues(alpha: 0.18);
        fg = AppColors.accentOrange;
        icon = Icons.bolt;
        break;
      case SettingsPillState.hidden:
        return const SizedBox.shrink();
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
