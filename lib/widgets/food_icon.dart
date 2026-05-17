import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_colors.dart';
import '../core/food_icon_map.dart';

class FoodIcon extends StatelessWidget {
  final String foodName;
  final double size;
  final Color? background;

  const FoodIcon({
    super.key,
    required this.foodName,
    this.size = 40,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final asset = FoodIconMap.assetFor(foodName);
    final bg = background ?? AppColors.sky50;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: asset != null
          ? SvgPicture.asset(asset, fit: BoxFit.contain)
          : Icon(
              Icons.restaurant_outlined,
              color: AppColors.sky700,
              size: size * 0.55,
            ),
    );
  }
}
