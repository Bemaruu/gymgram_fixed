import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_radius.dart';
import '../core/app_shadows.dart';
import '../core/app_spacing.dart';
import '../core/app_typography.dart';
import 'food_icon.dart';

class FoodItem {
  final String name;
  final int kcal;
  bool isChecked;

  FoodItem({
    required this.name,
    required this.kcal,
    this.isChecked = false,
  });

  FoodItem copyWith({
    String? name,
    int? kcal,
    bool? isChecked,
  }) {
    return FoodItem(
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class MealCard extends StatelessWidget {
  final String title;
  final List<FoodItem> foods;
  final Function(int index)? onToggle;

  const MealCard({
    Key? key,
    required this.title,
    required this.foods,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalKcal = foods.fold<int>(
      0,
      (sum, item) => sum + (item.isChecked ? item.kcal : 0),
    );

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.base,
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.h3.copyWith(color: AppColors.sky900),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$totalKcal kcal',
                style: AppTypography.numMd.copyWith(color: AppColors.ember400),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...foods.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            food.isChecked
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: food.isChecked
                                ? AppColors.sky400
                                : AppColors.neutral400,
                            size: 20,
                          ),
                          onPressed: () {
                            if (onToggle != null) {
                              onToggle!(index);
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        FoodIcon(foodName: food.name, size: 28),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            food.name,
                            style: AppTypography.body.copyWith(
                              color: AppColors.sky900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${food.kcal} kcal',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
