import 'package:flutter/material.dart';

enum ProfileTab { fotos, rutinas, recetas, rango, guardados }

class ProfileTabsNav extends StatelessWidget {
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onChanged;
  final bool showSaved;
  final bool showRango;

  const ProfileTabsNav({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showSaved = true,
    this.showRango = true,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <_TabSpec>[
      const _TabSpec(ProfileTab.fotos, Icons.grid_on_rounded),
      const _TabSpec(ProfileTab.rutinas, Icons.fitness_center_rounded),
      const _TabSpec(ProfileTab.recetas, Icons.restaurant_menu_rounded),
      if (showRango)
        const _TabSpec(ProfileTab.rango, Icons.workspace_premium_rounded),
      if (showSaved)
        const _TabSpec(ProfileTab.guardados, Icons.bookmark_border_rounded),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE)),
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final isActive = t.tab == selected;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(t.tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? const Color(0xFF00BFFF)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Icon(
                  t.icon,
                  color: isActive
                      ? const Color(0xFF00BFFF)
                      : Colors.black54,
                  size: 22,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TabSpec {
  final ProfileTab tab;
  final IconData icon;
  const _TabSpec(this.tab, this.icon);
}
