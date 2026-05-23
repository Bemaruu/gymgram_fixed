import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/ranked_profile_model.dart';
import '../services/ranked_service.dart';
import '../services/subscription_service.dart';
import '../ui/ranked/ranked_screen.dart';

/// Preview de Rango Fitness en la pestaña de perfil.
///
/// Perfil propio (userId == null):
///  - Free                     -> teaser candado
///  - Plus/Premium sin datos   -> card "Sin rango" tappable -> RankedScreen
///  - Plus/Premium con datos   -> tier + division + RP + mini progreso
///
/// Perfil ajeno (userId != null):
///  - Con datos   -> muestra su tier/RP (read-only, sin botón RankedScreen)
///  - Sin datos   -> "Sin rango aún"
class PremiumRankPreview extends StatefulWidget {
  final String? userId;
  const PremiumRankPreview({super.key, this.userId});

  @override
  State<PremiumRankPreview> createState() => _PremiumRankPreviewState();
}

class _PremiumRankPreviewState extends State<PremiumRankPreview> {
  static const Color _darkSurfaceCard = Color(0xFF1A1A2E);
  static const Color _accentOrange = Color(0xFFFF6B35);
  static const Color _gold = Color(0xFFFFD700);

  bool _loading = true;
  SubscriptionTier _tier = SubscriptionTier.free;
  RankedProfile? _profile;

  bool get _isOwnProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isOwnProfile) {
      final tier = await SubscriptionService.instance.currentTier();
      RankedProfile? profile;
      if (tier != SubscriptionTier.free) {
        profile = await RankedService.instance.getMyProfile();
      }
      if (!mounted) return;
      setState(() {
        _tier = tier;
        _profile = profile;
        _loading = false;
      });
    } else {
      final profile = await RankedService.instance.getProfileOf(widget.userId!);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  void _openRankedScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RankedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Perfil ajeno: solo muestra datos del otro usuario
    if (!_isOwnProfile) {
      return _profile != null
          ? _buildRankedCard(_profile!)
          : _buildUnrankedCard();
    }

    // Perfil propio
    if (_tier == SubscriptionTier.free) {
      return _buildFreeTeaser();
    }

    if (_profile == null) {
      return _buildUnrankedCard();
    }

    return _buildRankedCard(_profile!);
  }

  // ----- Estados -----

  Widget _buildFreeTeaser() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    PhosphorIconsFill.shield,
                    size: 72,
                    color: _gold.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: _accentOrange,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      PhosphorIconsFill.lock,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Modo Competitivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desbloquea con Plus',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: _accentOrange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Ver planes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tu constancia tendrá recompensa',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUnrankedCard() {
    const Color unrankedColor = Color(0xFF7A7A7A);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openRankedScreen,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _darkSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: unrankedColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: unrankedColor, width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsFill.question,
                color: Colors.white70,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin rango aún',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Completa tu primer entrenamiento',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankedCard(RankedProfile p) {
    final tierLabel = p.tierLabel();
    final divLabel = p.romanDivision();
    final progress = p.progressToNextTier();
    final (lo, hi) = p.tierRange();
    final isInmortal = p.tier == RankedTier.inmortal;
    final tierColor = _tierColor(p.tier);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isOwnProfile ? _openRankedScreen : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _darkSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsFill.shield,
                    color: tierColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInmortal ? tierLabel : '$tierLabel $divLabel',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.currentRp} RP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isInmortal ? 'Élite Inmortal' : '$lo - $hi RP al siguiente tier',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu constancia tendrá recompensa',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tierColor(RankedTier t) {
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
}
