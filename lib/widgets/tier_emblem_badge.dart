import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/ranked_profile_model.dart';

/// Emblema de tier reutilizable (SVG + aura RadialGradient).
/// Extraído del patrón de premium_rank_preview.dart para uso compartido.
class TierEmblemBadge extends StatelessWidget {
  final RankedTier tier;
  final double size;
  final bool animatedAura;

  const TierEmblemBadge({
    super.key,
    required this.tier,
    this.size = 56,
    this.animatedAura = false,
  });

  static Color colorOf(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return const Color(0xFF7A7A7A);
      case RankedTier.bronce:
        return const Color(0xFFB87333);
      case RankedTier.plata:
        return const Color(0xFFA0A8B0);
      case RankedTier.oro:
        return const Color(0xFFE2B23B);
      case RankedTier.platino:
        return const Color(0xFF4FC3D8);
      case RankedTier.diamante:
        return const Color(0xFF6A8DFF);
      case RankedTier.inmortal:
        return const Color(0xFFB14CFF);
    }
  }

  static String assetName(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return 'hierro';
      case RankedTier.bronce:
        return 'bronce';
      case RankedTier.plata:
        return 'plata';
      case RankedTier.oro:
        return 'oro';
      case RankedTier.platino:
        return 'platino';
      case RankedTier.diamante:
        return 'diamante';
      case RankedTier.inmortal:
        return 'inmortal';
    }
  }

  static String labelOf(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return 'Hierro';
      case RankedTier.bronce:
        return 'Bronce';
      case RankedTier.plata:
        return 'Plata';
      case RankedTier.oro:
        return 'Oro';
      case RankedTier.platino:
        return 'Platino';
      case RankedTier.diamante:
        return 'Diamante';
      case RankedTier.inmortal:
        return 'Inmortal';
    }
  }

  /// Tiers de baja luminosidad (Hierro, Plata) necesitan boost de aura
  /// para no perderse contra `darkSurface`.
  static bool _isLowLuminance(RankedTier t) =>
      t == RankedTier.hierro || t == RankedTier.plata;

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tier);
    final boost = _isLowLuminance(tier) ? 1.6 : 1.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: (0.35 * boost).clamp(0.0, 1.0)),
                  color.withValues(alpha: (0.10 * boost).clamp(0.0, 1.0)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/ranks/${assetName(tier)}.svg',
            width: size * 0.84,
            height: size * 0.84,
          ),
        ],
      ),
    );
  }
}
