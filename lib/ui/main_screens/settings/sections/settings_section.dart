import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(20, 8, 20, 0),
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      tiles.add(children[i]);
      if (i != children.length - 1) {
        tiles.add(const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.settingsDivider,
          indent: 56,
        ));
      }
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.settingsElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: tiles),
          ),
        ],
      ),
    );
  }
}
