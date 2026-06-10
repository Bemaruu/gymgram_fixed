import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_durations.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String? profileImageUrl;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.profileImageUrl,
  });

  ImageProvider _avatarImage() {
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(profileImageUrl!);
    }
    return const AssetImage('assets/images/default_profile.png');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral0,
        boxShadow: [
          BoxShadow(
            color: AppColors.sky900.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _NavItem(
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                  child: _PhosphorIconSwitcher(
                    isActive: currentIndex == 0,
                    activeIcon: PhosphorIconsFill.barbell,
                    inactiveIcon: PhosphorIconsRegular.barbell,
                  ),
                ),
                _NavItem(
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                  child: _PhosphorIconSwitcher(
                    isActive: currentIndex == 1,
                    activeIcon: PhosphorIconsFill.house,
                    inactiveIcon: PhosphorIconsRegular.house,
                  ),
                ),
                _NavItem(
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                  child: _PhosphorIconSwitcher(
                    isActive: currentIndex == 2,
                    activeIcon: PhosphorIconsFill.bowlFood,
                    inactiveIcon: PhosphorIconsRegular.bowlFood,
                  ),
                ),
                _NavItem(
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                  child: _AvatarItem(
                    isActive: currentIndex == 3,
                    image: _avatarImage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final Widget child;

  const _NavItem({
    required this.isActive,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: AppDurations.base,
              curve: AppDurations.emphasized,
              width: isActive ? 28 : 0,
              height: 4,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.auroraGradient : null,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhosphorIconSwitcher extends StatelessWidget {
  final bool isActive;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _PhosphorIconSwitcher({
    required this.isActive,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: AppDurations.base,
      curve: AppDurations.emphasized,
      scale: isActive ? 1.1 : 1.0,
      child: AnimatedSwitcher(
        duration: AppDurations.base,
        switchInCurve: AppDurations.emphasized,
        switchOutCurve: AppDurations.emphasized,
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          key: ValueKey<bool>(isActive),
          size: 26,
          color: isActive ? AppColors.sky700 : AppColors.neutral400,
        ),
      ),
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final bool isActive;
  final ImageProvider image;

  const _AvatarItem({required this.isActive, required this.image});

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 13,
      backgroundImage: image,
      backgroundColor: AppColors.neutral100,
    );

    return AnimatedScale(
      duration: AppDurations.base,
      curve: AppDurations.emphasized,
      scale: isActive ? 1.1 : 1.0,
      child: AnimatedContainer(
        duration: AppDurations.base,
        curve: AppDurations.emphasized,
        padding: EdgeInsets.all(isActive ? 2 : 0),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.auroraGradient : null,
          shape: BoxShape.circle,
        ),
        child: isActive
            ? Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: AppColors.neutral0,
                  shape: BoxShape.circle,
                ),
                child: avatar,
              )
            : avatar,
      ),
    );
  }
}
