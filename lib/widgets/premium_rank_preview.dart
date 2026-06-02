import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        border: Border.all(color: const Color(0xFF1F4368)),
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

  List<Widget> _buildMeasurementTicks(Color color) {
    // 4 ticks cardinales (12, 3, 6, 9) tangentes al borde interior del disco.
    // Disco Ø 78 → radio 39. Tick a 30dp del centro.
    const double radius = 30;
    final tickColor = color.withValues(alpha: 0.65);
    return [
      // 12 (top)
      Transform.translate(
        offset: const Offset(0, -radius),
        child: Container(width: 1, height: 5, color: tickColor),
      ),
      // 6 (bottom)
      Transform.translate(
        offset: const Offset(0, radius),
        child: Container(width: 1, height: 5, color: tickColor),
      ),
      // 3 (right)
      Transform.translate(
        offset: const Offset(radius, 0),
        child: Container(width: 5, height: 1, color: tickColor),
      ),
      // 9 (left)
      Transform.translate(
        offset: const Offset(-radius, 0),
        child: Container(width: 5, height: 1, color: tickColor),
      ),
    ];
  }

  Widget _buildUnrankedCard() {
    const Color silver = Color(0xFFB8C5D6);
    const Color silverDeep = Color(0xFF6B7C90);
    const Color skyAccent = Color(0xFF63C8FC);
    const Color trackBg = Color(0xFF13314E);

    // TODO: cuando exista lógica real de entrenamientos hacia BRONCE, cablear.
    const totalRequired = 5;
    const completed = 0;
    const remaining = totalRequired - completed;
    const percent = (completed * 100) ~/ totalRequired;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _isOwnProfile ? _openRankedScreen : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2238), Color(0xFF091D2E)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: silver.withValues(alpha: 0.18), width: 1),
          boxShadow: [
            BoxShadow(
              color: skyAccent.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: pill RANKED + Ver detalles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        silver.withValues(alpha: 0.08),
                        silver.withValues(alpha: 0.18),
                        silver.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: silver.withValues(alpha: 0.55), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: skyAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: skyAccent.withValues(alpha: 0.80),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(
                            begin: 0.6,
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(width: 6),
                      const Text(
                        'RANKED',
                        style: TextStyle(
                          color: silver,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isOwnProfile)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver detalles',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // Body: emblema + datos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Capa 1: halo radial externo pulsante
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    skyAccent.withValues(alpha: 0.22),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            )
                                .animate(
                                  onPlay: (c) => c.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(0.92, 0.92),
                                  end: const Offset(1.08, 1.08),
                                  duration: 2400.ms,
                                  curve: Curves.easeInOut,
                                ),
                            // Capa 3: disco base plata cóncavo
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  stops: const [0.0, 0.6, 1.0],
                                  colors: [
                                    silver.withValues(alpha: 0.05),
                                    silver.withValues(alpha: 0.18),
                                    silverDeep.withValues(alpha: 0.28),
                                  ],
                                ),
                                border: Border.all(
                                  color: silver.withValues(alpha: 0.85),
                                  width: 1.2,
                                ),
                              ),
                              // Sombra interna (concavidad)
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.transparent,
                                      const Color(0xFF091D2E)
                                          .withValues(alpha: 0.40),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Capa 5: 4 ticks de medición (12/3/6/9)
                            ..._buildMeasurementTicks(silver),
                            // Capa 4: núcleo pulsante (latido)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  stops: const [0.0, 0.4, 1.0],
                                  colors: [
                                    Colors.white.withValues(alpha: 0.95),
                                    skyAccent.withValues(alpha: 0.85),
                                    skyAccent.withValues(alpha: 0.0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: skyAccent.withValues(alpha: 0.55),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                            )
                                .animate(
                                  onPlay: (c) => c.repeat(reverse: true),
                                )
                                .scale(
                                  begin: const Offset(0.85, 0.85),
                                  end: const Offset(1.15, 1.15),
                                  duration: 1400.ms,
                                  curve: Curves.easeInOut,
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.0, 0.5, 1.0],
                          colors: [
                            Colors.white,
                            silver,
                            Colors.white,
                          ],
                        ).createShader(rect),
                        blendMode: BlendMode.srcIn,
                        child: const Text(
                          'ASPIRANTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                            shadows: [
                              Shadow(
                                color: Color(0x4D63C8FC),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tu viaje recién comienza',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                          children: const [
                            TextSpan(text: 'Te faltan '),
                            TextSpan(
                              text: '$remaining entrenamientos',
                              style: TextStyle(
                                color: skyAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                                text:
                                    ' para que GymGram calcule tu rango inicial.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (var i = 0; i < totalRequired; i++) ...[
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i < completed ? null : trackBg,
                                  gradient: i < completed
                                      ? const LinearGradient(
                                          colors: [
                                            skyAccent,
                                            Color(0xFF7DCFFC),
                                          ],
                                        )
                                      : null,
                                  border: i >= completed
                                      ? Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.05),
                                          width: 1,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (i < totalRequired - 1)
                              const SizedBox(width: 3),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: completed > 0
                                  ? skyAccent
                                  : silver.withValues(alpha: 0.55),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '$completed / $totalRequired completados',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        skyAccent.withValues(alpha: 0.22),
                        silver.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: skyAccent.withValues(alpha: 0.40),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    PhosphorIconsFill.sparkle,
                    size: 16,
                    color: skyAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EVALUACIÓN INICIAL',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.50),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'TU PRIMER RANGO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Se asignará según tus PRs y rendimiento',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(18),
      onTap: _isOwnProfile ? _openRankedScreen : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _darkSurfaceCard,
              Color.lerp(_darkSurfaceCard, tierColor, 0.10) ?? _darkSurfaceCard,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tierColor.withValues(alpha: 0.28), width: 1),
          boxShadow: [
            BoxShadow(
              color: tierColor.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Emblema SVG con aura del tier
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              tierColor.withValues(
                                  alpha: _isLowLuminanceTier(p.tier) ? 0.55 : 0.35),
                              tierColor.withValues(
                                  alpha: _isLowLuminanceTier(p.tier) ? 0.15 : 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/ranks/${_assetName(p.tier)}.svg',
                        width: 58,
                        height: 58,
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: const Duration(milliseconds: 2400),
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.04, 1.04),
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isInmortal ? tierLabel : '$tierLabel $divLabel',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: tierColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${p.currentRp} RP',
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isOwnProfile)
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isInmortal ? 'Élite Inmortal' : '$lo - $hi RP',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isInmortal)
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: tierColor.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tu constancia tendrá recompensa',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _assetName(RankedTier t) {
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

  /// Hierro y Plata son colores grisáceos: necesitan más alpha en el aura para
  /// no perderse contra el fondo dark.
  bool _isLowLuminanceTier(RankedTier t) =>
      t == RankedTier.hierro || t == RankedTier.plata;

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
