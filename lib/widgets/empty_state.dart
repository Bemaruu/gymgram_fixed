import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: AppColors.morningGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.sky700),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              style: AppTypography.body.copyWith(color: AppColors.neutral600),
              textAlign: TextAlign.center,
            ),
          ],
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ember400,
                foregroundColor: AppColors.neutral0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.base),
                ),
              ),
              child: Text(
                ctaLabel!,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.neutral0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
