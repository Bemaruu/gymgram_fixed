import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../models/ranked_profile_model.dart';
import 'ranked_screen.dart';
import 'tier_reveal_card.dart';

/// Overlay full-screen del ascenso de tier. Reemplaza el dialog plano.
///
/// Un solo [AnimationController] gobierna toda la secuencia mediante
/// Intervals. La detección de ascenso vive en RankedScreen; este widget solo
/// presenta el momento.
class TierUpOverlay extends StatefulWidget {
  final RankedTier oldTier;
  final RankedProfile profile;
  final String username;

  const TierUpOverlay({
    super.key,
    required this.oldTier,
    required this.profile,
    required this.username,
  });

  /// Empuja el overlay como ruta opaca-transparente full-screen.
  static Future<void> show(
    BuildContext context, {
    required RankedTier oldTier,
    required RankedProfile profile,
    required String username,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0xE6040E18),
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => TierUpOverlay(
          oldTier: oldTier,
          profile: profile,
          username: username,
        ),
      ),
    );
  }

  @override
  State<TierUpOverlay> createState() => _TierUpOverlayState();
}

class _TierUpOverlayState extends State<TierUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final GlobalKey _cardKey = GlobalKey();

  bool _isInmortal = false;
  late int _totalMs;

  // Fracciones de fase (0..1) calculadas sobre la duración total.
  late final double _fEnterEnd;
  late final double _fFillStart;
  late final double _fFillEnd;
  late final double _fOverloadStart;
  late final double _fOverloadEnd;
  late final double _fFlashStart;
  late final double _fFlashEnd;
  late final double _fRevealStart;
  late final double _fRevealEnd;
  late final double _fTextStart;
  late final double _fTextEnd;
  late final double _fSettleStart;

  late final Animation<double> _enter;
  late final Animation<double> _fill;
  late final Animation<double> _overload;
  late final Animation<double> _flash;
  late final Animation<double> _reveal;
  late final Animation<double> _textIn;
  late final Animation<double> _settle;

  // Control de háptica por fase para no repetir.
  bool _hapticOverload = false;
  bool _hapticFlash = false;
  bool _hapticReveal = false;
  final Set<int> _fillTicks = {};

  RankedTier get _newTier => widget.profile.tier;

  @override
  void initState() {
    super.initState();
    _isInmortal = _newTier == RankedTier.inmortal;
    _totalMs = _isInmortal ? 5500 : 4200;

    // Anclas en ms de la spec, normalizadas a la duración total (_totalMs).
    // Para Inmortal (_totalMs = 5500) las fases caen antes en la línea y el
    // settle final ocupa el aire extra, dando la sensación épica más larga.
    _fEnterEnd = _norm(300);
    _fFillStart = _norm(300);
    _fFillEnd = _norm(1500);
    _fOverloadStart = _norm(1500);
    _fOverloadEnd = _norm(1650);
    _fFlashStart = _norm(1650);
    _fFlashEnd = _norm(1750);
    _fRevealStart = _norm(1750);
    _fRevealEnd = _norm(2600);
    _fTextStart = _norm(2200);
    _fTextEnd = _norm(2900);
    _fSettleStart = _norm(2900);

    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..addListener(_onTick);

    _enter = _curved(_fEnterEnd > 0 ? 0 : 0, _fEnterEnd, Curves.easeOut);
    _fill = _curved(_fFillStart, _fFillEnd, Curves.easeInOutCubic);
    _overload = _curved(_fOverloadStart, _fOverloadEnd, Curves.easeInOut);
    _flash = _curved(_fFlashStart, _fFlashEnd, Curves.linear);
    _reveal = _curved(_fRevealStart, _fRevealEnd, Curves.elasticOut);
    _textIn = _curved(_fTextStart, _fTextEnd, Curves.easeOutBack);
    _settle = _curved(_fSettleStart, 1.0, Curves.easeOut);

    HapticFeedback.selectionClick();
    _c.forward();
  }

  double _norm(int ms) => (ms / _totalMs).clamp(0.0, 1.0);

  Animation<double> _curved(double a, double b, Curve curve) {
    final lo = a.clamp(0.0, 1.0);
    final hi = b.clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _c,
      curve: Interval(lo, hi == lo ? (lo + 0.001).clamp(0.0, 1.0) : hi,
          curve: curve),
    );
  }

  void _onTick() {
    final v = _c.value;

    // Fill: 5 lightImpact ascendentes (~cada 240ms entre 300 y 1500).
    if (v >= _fFillStart && v < _fOverloadStart) {
      final span = _fFillEnd - _fFillStart;
      if (span > 0) {
        final p = ((v - _fFillStart) / span).clamp(0.0, 1.0);
        final idx = (p * 5).floor().clamp(0, 4);
        if (_fillTicks.add(idx)) {
          HapticFeedback.lightImpact();
        }
      }
    }
    if (!_hapticOverload && v >= _fOverloadStart) {
      _hapticOverload = true;
      HapticFeedback.mediumImpact();
    }
    if (!_hapticFlash && v >= _fFlashStart) {
      _hapticFlash = true;
      HapticFeedback.heavyImpact();
    }
    if (!_hapticReveal && v >= _fRevealStart) {
      _hapticReveal = true;
      HapticFeedback.heavyImpact();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _swapped => _c.value >= (_fFlashStart + _fFlashEnd) / 2;

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      // pixelRatio que lleva 360x640 a 1080x1920.
      const pixelRatio = 3.0;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final file = await _writeTemp(bytes);
      final tier = tierLabelOf(_newTier);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Acabo de subir a $tier en GymGram 🔥 #GymGram',
      );
    } catch (_) {
      // Silencioso: compartir es secundario al momento.
    }
  }

  Future<dynamic> _writeTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/gymgram_rank_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(bytes);
    return f;
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final color = tierColorOf(_newTier);
    final v = _c.value;
    final showButtons = v >= _fSettleStart;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo + vignette.
          Positioned.fill(
            child: Opacity(
              opacity: _enter.value,
              child: _Background(isInmortal: _isInmortal),
            ),
          ),

          // Oleadas púrpura (solo Inmortal) antes del flash.
          if (_isInmortal && v < _fFlashStart)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _InmortalWavesPainter(
                    progress: (v / _fFlashStart).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),

          // Contenido central.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEmblemStage(color),
                _buildRpBar(color),
                const SizedBox(height: 18),
                _buildTexts(color),
              ],
            ),
          ),

          // Shockwave + burst (durante/después del reveal).
          if (v >= _fRevealStart)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RevealEffectsPainter(
                    revealValue: _reveal.value,
                    settleValue: _settle.value,
                    color: _isInmortal ? const Color(0xFFE9CDFF) : color,
                    particleCount: _isInmortal ? 40 : 24,
                    isInmortal: _isInmortal,
                  ),
                ),
              ),
            ),

          // FLASH white-out / dorado.
          if (v >= _fFlashStart && v < _fRevealStart + 0.02)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity:
                      (math.sin(_flash.value * math.pi)).clamp(0.0, 1.0),
                  child: Container(
                    color: _isInmortal
                        ? const Color(0xFFFFF6D6)
                        : Colors.white,
                  ),
                ),
              ),
            ),

          // Botones de cierre / compartir (fase settle).
          if (showButtons)
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Opacity(
                opacity: _settle.value.clamp(0.0, 1.0),
                child: _buildButtons(color),
              ),
            ),

          // Tarjeta compartible fuera de pantalla (siempre montada para
          // poder capturarla al instante).
          Positioned(
            left: -2000,
            top: 0,
            child: RepaintBoundary(
              key: _cardKey,
              child: TierRevealCard(
                profile: widget.profile,
                username: widget.username,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de RP de la fase de tensión (300-1500ms): se llena hasta el umbral
  /// recién cruzado, pulsa al 100% en el overload y se desvanece en el flash.
  Widget _buildRpBar(Color color) {
    final v = _c.value;
    if (_swapped || v >= _fRevealStart) return const SizedBox.shrink();

    // Opacidad: entra con el fondo, se desvanece durante el flash.
    double opacity;
    if (v >= _fFlashStart) {
      final span = _fRevealStart - _fFlashStart;
      opacity = span > 0 ? (1 - (v - _fFlashStart) / span).clamp(0.0, 1.0) : 0.0;
    } else {
      opacity = _enter.value.clamp(0.0, 1.0);
    }
    if (opacity <= 0) return const SizedBox.shrink();

    // RP objetivo = umbral cruzado (lo del tier nuevo). Cuenta hacia arriba.
    final crossed = widget.profile.tierRange().$1;
    final startRp = (crossed * 0.85).round();
    final shownRp = (startRp + (crossed - startRp) * _fill.value).round();

    // Pulso al 100% durante el overload (parábola que pico en mitad de fase).
    final pulse = 1.0 + (_overload.value * (1 - _overload.value) * 4) * 0.18;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$shownRp RP',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Transform.scale(
              scaleY: pulse,
              child: Container(
                width: 220,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _fill.value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.7),
                            Color.lerp(color, Colors.white, 0.6)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmblemStage(Color color) {
    final v = _c.value;
    final tierToShow = _swapped ? _newTier : widget.oldTier;

    // Shake horizontal en overload (±4px con sin) sobre el emblema viejo.
    double shake = 0;
    if (v >= _fOverloadStart && v < _fFlashStart && !_swapped) {
      final span = _fFlashStart - _fOverloadStart;
      final p = span > 0 ? (v - _fOverloadStart) / span : 0.0;
      shake = math.sin(p * math.pi * 6) * 4;
    }

    // Tamaño / escala: 110 antes, 180 final via elasticOut en reveal.
    double size = 110;
    double scale = 1.0;
    if (_swapped) {
      size = 180;
      scale = _reveal.value; // elasticOut 0..1 (overshoot incluido)
    }

    // Glow: máximo en overload y reveal.
    double glowBlur = 20;
    if (v >= _fOverloadStart && v < _fFlashStart) {
      final span = _fFlashStart - _fOverloadStart;
      final p = span > 0 ? (v - _fOverloadStart) / span : 0.0;
      glowBlur = 20 + p * 40;
    } else if (_swapped) {
      glowBlur = 20 + (_reveal.value.clamp(0.0, 1.0)) * 40;
    }

    final emblem = Transform.translate(
      offset: Offset(shake, 0),
      child: Transform.scale(
        scale: scale <= 0 ? 0.01 : scale,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tierColorOf(tierToShow)
                    .withValues(alpha: _swapped ? 0.9 : 0.6),
                blurRadius: glowBlur,
                spreadRadius: glowBlur * 0.15,
              ),
            ],
          ),
          child: TierEmblem(
            tier: tierToShow,
            size: size,
            animated: _swapped && v >= _fSettleStart,
          ),
        ),
      ),
    );

    // Capa de "agrietamiento" sobre el emblema de Diamante (solo Inmortal,
    // justo antes del flash).
    if (_isInmortal && !_swapped && v >= _fOverloadStart) {
      final span = _fFlashStart - _fOverloadStart;
      final crack = span > 0
          ? ((v - _fOverloadStart) / span).clamp(0.0, 1.0)
          : 0.0;
      return SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Emblema viejo al 70% en la entrada.
            Opacity(opacity: 0.85, child: emblem),
            IgnorePointer(
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _CrackPainter(progress: crack),
              ),
            ),
          ],
        ),
      );
    }

    // En la entrada el emblema viejo va al 70% de opacidad.
    final entering = v < _fFillStart;
    return Opacity(opacity: entering ? 0.70 : 1.0, child: emblem);
  }

  Widget _buildTexts(Color color) {
    final v = _c.value;
    if (v < _fFillStart) {
      // Aún en fase de entrada: sin textos de ascenso.
      return const SizedBox(height: 60);
    }

    final label = tierLabelOf(_newTier);
    final division = widget.profile.romanDivision();
    final title = _isInmortal || division.isEmpty
        ? label.toUpperCase()
        : '${label.toUpperCase()} $division';

    // "ASCENSO" cae con fade (fase texto).
    final ascensoOpacity =
        ((v - _fTextStart) / (_fTextEnd - _fTextStart)).clamp(0.0, 1.0);
    final ascensoDy = (1 - ascensoOpacity) * -16;
    final letterSpacing = 2 + (1 - _textIn.value) * 6;

    final showText = v >= _fTextStart;
    final showSub = _newTier == RankedTier.diamante ||
        _newTier == RankedTier.inmortal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showText) ...[
          Opacity(
            opacity: ascensoOpacity,
            child: Transform.translate(
              offset: Offset(0, ascensoDy),
              child: const Text(
                'ASCENSO',
                style: TextStyle(
                  color: AppColors.accentOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Transform.scale(
            scale: _textIn.value.clamp(0.0, 1.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: letterSpacing,
              ),
            ),
          ),
          if (_isInmortal) ...[
            const SizedBox(height: 10),
            Opacity(
              opacity: ascensoOpacity,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFE9CDFF), width: 1),
                ),
                child: const Text(
                  'TOP 500 GLOBAL · ÉLITE MUNDIAL',
                  style: TextStyle(
                    color: Color(0xFFE9CDFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (showSub) ...[
            const SizedBox(height: 8),
            Opacity(
              opacity: ascensoOpacity,
              child: const Text(
                'Pocos llegan aquí. Demuéstralo.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ] else
          const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildButtons(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _share,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'COMPARTIR MI RANGO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _close,
            style: TextButton.styleFrom(foregroundColor: Colors.white60),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Fondo con vignette (y gradiente radial púrpura para Inmortal)
// ============================================================

class _Background extends StatelessWidget {
  final bool isInmortal;
  const _Background({required this.isInmortal});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isInmortal
            ? const RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.2,
                colors: [Color(0xFF1A0A2E), Color(0xFF040E18)],
              )
            : const RadialGradient(
                center: Alignment(0, -0.1),
                radius: 1.3,
                colors: [Color(0xFF0A1726), Color(0xFF040E18)],
              ),
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.0,
            colors: [Colors.transparent, Color(0xCC000000)],
            stops: [0.55, 1.0],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

// ============================================================
// Shockwave + burst de partículas en el reveal
// ============================================================

class _RevealEffectsPainter extends CustomPainter {
  final double revealValue;
  final double settleValue;
  final Color color;
  final int particleCount;
  final bool isInmortal;

  _RevealEffectsPainter({
    required this.revealValue,
    required this.settleValue,
    required this.color,
    required this.particleCount,
    required this.isInmortal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = revealValue.clamp(0.0, 1.0);

    // Shockwave: anillo expandiéndose, se desvanece.
    if (t > 0 && t < 1.2) {
      final r = t * size.shortestSide * 0.7;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1 - t).clamp(0.0, 1.0) * 6 + 1
        ..color = color.withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.7);
      canvas.drawCircle(c, r, ringPaint);
    }

    // Rayos radiales (solo Inmortal).
    if (isInmortal && t > 0) {
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE9CDFF)
            .withValues(alpha: (1 - t).clamp(0.0, 1.0) * 0.5);
      for (int i = 0; i < 12; i++) {
        final a = (i / 12) * 2 * math.pi;
        final len = t * size.shortestSide * 0.6;
        canvas.drawLine(
          c,
          Offset(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len),
          rayPaint,
        );
      }
    }

    // Burst de partículas: salen del centro y caen con settle.
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    final spread = t * size.shortestSide * 0.55;
    final fall = settleValue * size.height * 0.35;
    for (int i = 0; i < particleCount; i++) {
      final a = (i / particleCount) * 2 * math.pi +
          rng.nextDouble() * 0.4;
      final dist = spread * (0.5 + rng.nextDouble() * 0.5);
      final px = c.dx + math.cos(a) * dist;
      final py = c.dy + math.sin(a) * dist + fall;
      final alpha = (1 - settleValue).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha * 0.85);
      canvas.drawCircle(
          Offset(px, py), 2 + rng.nextDouble() * 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RevealEffectsPainter old) =>
      old.revealValue != revealValue ||
      old.settleValue != settleValue ||
      old.color != color;
}

// ============================================================
// Oleadas de glow púrpura (Inmortal, antes del flash)
// ============================================================

class _InmortalWavesPainter extends CustomPainter {
  final double progress; // 0..1 hasta el flash
  _InmortalWavesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (int i = 0; i < 3; i++) {
      final phase = (progress * 3 - i).clamp(0.0, 1.0);
      if (phase <= 0) continue;
      final r = phase * size.shortestSide * 0.7;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFB14CFF)
            .withValues(alpha: (1 - phase).clamp(0.0, 1.0) * 0.4);
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InmortalWavesPainter old) =>
      old.progress != progress;
}

// ============================================================
// Fracturas sobre el emblema de Diamante (Inmortal, pre-swap)
// ============================================================

class _CrackPainter extends CustomPainter {
  final double progress; // 0..1
  _CrackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    final rng = math.Random(11);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: progress * 0.9);
    for (int i = 0; i < 7; i++) {
      final a = (i / 7) * 2 * math.pi + rng.nextDouble() * 0.5;
      final path = Path()..moveTo(c.dx, c.dy);
      var p = c;
      final segs = 3;
      for (int s = 1; s <= segs; s++) {
        final reach = (size.shortestSide * 0.45) * progress * (s / segs);
        final jitter = (rng.nextDouble() - 0.5) * 0.6;
        final na = a + jitter;
        p = Offset(c.dx + math.cos(na) * reach, c.dy + math.sin(na) * reach);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter old) =>
      old.progress != progress;
}
