import 'package:flutter/material.dart';
import 'settings_pill.dart';

class SettingsTile extends StatelessWidget {
  final IconData? leadingIcon;
  final Color? leadingColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final SettingsPillState pillState;
  final String pillLabel;
  final bool showChevron;
  final Color? titleColor;

  const SettingsTile({
    super.key,
    this.leadingIcon,
    this.leadingColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.pillState = SettingsPillState.hidden,
    this.pillLabel = '',
    this.showChevron = true,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: leadingColor ?? Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (pillState != SettingsPillState.hidden) ...[
              const SizedBox(width: 8),
              SettingsPill(state: pillState, label: pillLabel),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (showChevron && trailing == null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
