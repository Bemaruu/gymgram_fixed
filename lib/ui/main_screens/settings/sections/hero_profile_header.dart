import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';
import '../../../../services/subscription_service.dart';

class HeroProfileHeader extends StatelessWidget {
  final String fullName;
  final String username;
  final String? avatarUrl;
  final File? localAvatar;
  final bool uploadingAvatar;
  final SubscriptionTier tier;
  final VoidCallback onChangeAvatar;

  const HeroProfileHeader({
    super.key,
    required this.fullName,
    required this.username,
    required this.avatarUrl,
    required this.localAvatar,
    required this.uploadingAvatar,
    required this.tier,
    required this.onChangeAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 124,
                  height: 124,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.accentOrange,
                        AppColors.primary,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.settingsSurface,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(child: _avatarImage()),
                  ),
                ),
                if (uploadingAvatar)
                  Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: uploadingAvatar ? null : onChangeAvatar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.settingsSurface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fullName.isNotEmpty ? fullName : username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@$username',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          _TierPill(tier: tier),
        ],
      ),
    );
  }

  Widget _avatarImage() {
    if (localAvatar != null) {
      return Image.file(localAvatar!, fit: BoxFit.cover);
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: AppColors.settingsElevated),
        errorWidget: (_, __, ___) =>
            Image.asset('assets/images/default_profile.png', fit: BoxFit.cover),
      );
    }
    return Image.asset('assets/images/default_profile.png', fit: BoxFit.cover);
  }
}

class _TierPill extends StatelessWidget {
  final SubscriptionTier tier;
  const _TierPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    switch (tier) {
      case SubscriptionTier.free:
        return _pill(
          label: 'Free',
          gradient: null,
          bg: AppColors.settingsElevated,
          fg: Colors.white,
          border: Colors.white12,
        );
      case SubscriptionTier.plus:
        return _pill(
          label: 'Plus',
          gradient: const LinearGradient(
            colors: [Color(0xFF63C8FC), Color(0xFF1479AA)],
          ),
          fg: Colors.white,
        );
      case SubscriptionTier.premium:
        return _pill(
          label: 'Premium',
          icon: Icons.bolt,
          gradient: const LinearGradient(
            colors: [AppColors.accentOrange, Color(0xFFFFB341)],
          ),
          fg: Colors.white,
        );
    }
  }

  Widget _pill({
    required String label,
    LinearGradient? gradient,
    Color? bg,
    Color? border,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
