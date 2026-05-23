import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/app_colors.dart';
import '../../models/ranked_profile_model.dart';
import 'ranked_screen.dart';

/// Tarjeta 9:16 exportable a PNG (1080x1920) para compartir el ascenso.
///
/// Diseñada para renderizarse dentro de un [RepaintBoundary] a pixelRatio
/// fijo. La composición no anima: las partículas son estáticas para que el
/// snapshot sea determinista.
class TierRevealCard extends StatelessWidget {
  final RankedProfile profile;
  final String username;

  /// Lado lógico de referencia. El RepaintBoundary se captura con un
  /// pixelRatio que lleva esto a 1080x1920.
  static const double logicalWidth = 360;
  static const double logicalHeight = 640;

  const TierRevealCard({
    super.key,
    required this.profile,
    required this.username,
  });

  bool get _isInmortal => profile.tier == RankedTier.inmortal;

  @override
  Widget build(BuildContext context) {
    final color = tierColorOf(profile.tier);
    final label = tierLabelOf(profile.tier);
    final division = profile.romanDivision();
    final title = _isInmortal || division.isEmpty
        ? label.toUpperCase()
        : '${label.toUpperCase()} $division';

    return SizedBox(
      width: logicalWidth,
      height: logicalHeight,
      child: Container(
        decoration: BoxDecoration(
          gradient: _isInmortal
              ? const RadialGradient(
                  center: Alignment(0, -0.25),
                  radius: 1.1,
                  colors: [Color(0xFF1A0A2E), Color(0xFF040E18)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1A2A), Color(0xFF040E18)],
                ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StaticParticlesPainter(
                  color: _isInmortal ? const Color(0xFFE9CDFF) : color,
                  count: _isInmortal ? 40 : 24,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const Spacer(flex: 2),
                  _hero(color, title),
                  const Spacer(flex: 1),
                  _pillars(),
                  const Spacer(flex: 2),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Text(
          'GymGram',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        Text(
          '@$username',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _hero(Color color, String title) {
    final glow = _isInmortal ? const Color(0xFFB14CFF) : color;
    return Column(
      children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                glow.withValues(alpha: 0.45),
                glow.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          alignment: Alignment.center,
          child: TierEmblem(tier: profile.tier, size: 190, animated: false),
        ),
        const SizedBox(height: 8),
        const Text(
          'ASCENSO',
          style: TextStyle(
            color: AppColors.accentOrange,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${profile.currentRp} RP',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _pillars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _pillar(PhosphorIconsFill.barbell, 'Fuerza', profile.strengthScore),
        _pillar(PhosphorIconsFill.flame, 'Constancia', profile.consistencyScore),
        _pillar(PhosphorIconsFill.users, 'Comunidad', profile.communityScore),
        _pillar(PhosphorIconsFill.target, 'Reto', profile.challengeScore),
      ],
    );
  }

  Widget _pillar(IconData icon, String label, int value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accentOrange, size: 22),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _footer() {
    return const Text(
      'GymGram · Sube tu rango',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white60,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StaticParticlesPainter extends CustomPainter {
  final Color color;
  final int count;
  _StaticParticlesPainter({required this.color, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 1.0 + rng.nextDouble() * 2.5;
      paint.color = color.withValues(alpha: 0.15 + rng.nextDouble() * 0.45);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticParticlesPainter old) =>
      old.color != color || old.count != count;
}
