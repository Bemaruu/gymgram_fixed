import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class DangerZone extends StatelessWidget {
  final VoidCallback onDeleteAccount;

  const DangerZone({super.key, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'ZONA PELIGROSA',
              style: TextStyle(
                color: AppColors.settingsDanger.withValues(alpha: 0.9),
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
              border: Border.all(
                color: AppColors.settingsDanger.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onDeleteAccount,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.settingsDanger,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eliminar cuenta',
                            style: TextStyle(
                              color: AppColors.settingsDanger,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Esta accion es permanente e irreversible.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.settingsDanger.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
