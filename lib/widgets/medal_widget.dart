import 'package:flutter/material.dart';
import '../models/badge_model.dart';

/// Widget circular de medalla. Muestra la imagen PNG del asset o un ícono
/// de respaldo si la imagen aún no existe. Soporta estado bloqueado/ganado.
class MedalWidget extends StatelessWidget {
  final BadgeModel badge;
  final bool isEarned;
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;

  const MedalWidget({
    super.key,
    required this.badge,
    required this.isEarned,
    this.size = 60,
    this.showLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = badge.rank.color;
    final child = GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircle(rankColor),
          if (showLabel) ...[
            const SizedBox(height: 5),
            SizedBox(
              width: size + 8,
              child: Text(
                badge.medalName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isEarned ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return child;
  }

  Widget _buildCircle(Color rankColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: isEarned
              ? [
                  rankColor.withValues(alpha: 0.35),
                  const Color(0xFF0A0A14),
                ]
              : [
                  Colors.grey.shade800,
                  Colors.grey.shade900,
                ],
        ),
        border: Border.all(
          color: isEarned
              ? rankColor.withValues(alpha: 0.9)
              : Colors.grey.shade700,
          width: size > 50 ? 2.5 : 1.5,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.45),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.04,
                ),
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildImage(rankColor),
          if (!isEarned) _buildLockOverlay(),
        ],
      ),
    );
  }

  Widget _buildImage(Color rankColor) {
    final iconSize = size * 0.42;
    return ClipOval(
      child: Image.asset(
        badge.imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        color: isEarned ? null : Colors.grey.shade700,
        colorBlendMode: isEarned ? null : BlendMode.saturation,
        errorBuilder: (_, __, ___) => Icon(
          badge.rank.icon,
          size: iconSize,
          color: isEarned ? rankColor : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
      ),
      child: Icon(
        Icons.lock,
        size: size * 0.3,
        color: Colors.white38,
      ),
    );
  }
}

/// Chip pequeño que muestra el rango de una medalla (Bronce, Plata, etc.)
class RankChip extends StatelessWidget {
  final BadgeRank rank;

  const RankChip({super.key, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: rank.color.withValues(alpha: 0.18),
        border: Border.all(color: rank.color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rank.label,
        style: TextStyle(
          color: rank.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
