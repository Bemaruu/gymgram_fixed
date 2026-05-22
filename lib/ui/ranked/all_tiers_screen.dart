import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/ranked_profile_model.dart';
import 'ranked_screen.dart';

/// Pantalla informativa con todos los tiers del sistema ranked.
class AllTiersScreen extends StatelessWidget {
  final RankedTier? currentTier;
  const AllTiersScreen({super.key, this.currentTier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Sistema de rangos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sistema de rangos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sube de tier ganando RP en los 4 pilares. Cada temporada dura 3 meses.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            for (final tier in RankedTier.values)
              _TierCard(
                tier: tier,
                isCurrent: tier == currentTier,
              ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final RankedTier tier;
  final bool isCurrent;
  const _TierCard({required this.tier, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final color = tierColorOf(tier);
    final perks = _perksFor(tier);
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFF6B35), width: 2)
            : null,
      ),
      child: Stack(
        children: [
          Row(
            children: [
              TierEmblem(tier: tier, size: 72, animated: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _tierName(tier).toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rpRange(tier),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: perks.map(_perkChip).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCurrent)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TU RANGO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _perkChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _tierName(RankedTier t) {
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

  static String _rpRange(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return '0-400 RP';
      case RankedTier.bronce:
        return '400-1000 RP';
      case RankedTier.plata:
        return '1000-1800 RP';
      case RankedTier.oro:
        return '1800-2800 RP';
      case RankedTier.platino:
        return '2800-4000 RP';
      case RankedTier.diamante:
        return '4000-6000 RP';
      case RankedTier.inmortal:
        return '6000+ RP';
    }
  }

  static List<String> _perksFor(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return const ['Punto de partida', 'Sin decay'];
      case RankedTier.bronce:
        return const ['Sin decay', 'Misiones semanales'];
      case RankedTier.plata:
        return const ['Decay -15 RP/48h', 'Competencia real'];
      case RankedTier.oro:
        return const ['Marco animado', 'Recap detallado'];
      case RankedTier.platino:
        return const ['Marco premium', 'Top 10% global'];
      case RankedTier.diamante:
        return const ['Marco permanente', 'Top 3%', 'Aura partículas'];
      case RankedTier.inmortal:
        return const ['Top 500 numerado', 'Aura legendaria', 'Marco eterno'];
    }
  }
}
