import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/food_scan_service.dart';

/// Resultado retornado al hacer `Navigator.pop` desde la pantalla cinemática.
class FoodScanAnimationResult {
  final ScanResult? success;
  final ScanException? error;
  const FoodScanAnimationResult({this.success, this.error});
}

/// Pantalla full-screen cinemática que muestra la foto del plato siendo
/// escaneada mientras la edge function `scan-food` corre en segundo plano.
class FoodScanAnimationScreen extends StatefulWidget {
  final File imageFile;
  final Future<ScanResult> scanFuture;

  const FoodScanAnimationScreen({
    super.key,
    required this.imageFile,
    required this.scanFuture,
  });

  @override
  State<FoodScanAnimationScreen> createState() =>
      _FoodScanAnimationScreenState();
}

class _FoodScanAnimationScreenState extends State<FoodScanAnimationScreen>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF00BFFF);

  late final AnimationController _scanLineCtrl;
  late final AnimationController _reticleCtrl;
  late final AnimationController _hudCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _completeCtrl;

  // Estados que rotan en el HUD.
  static const _stages = [
    'Detectando alimentos…',
    'Calculando macros…',
    'Estimando porciones…',
    'Validando con la IA…',
  ];
  int _stageIndex = 0;

  // Targets fake del retículo (porcentajes de la foto). Cambian cada ciclo.
  final _rnd = math.Random();
  Offset _reticleFrom = const Offset(0.3, 0.4);
  Offset _reticleTo = const Offset(0.65, 0.6);

  // Stats falsas que aparecen junto al retículo.
  static const _fakeStats = [
    'kcal: ~280',
    'prot: 18g',
    'carb: 32g',
    'grasa: 11g',
    'fibra: 4g',
    'porción: ~200g',
  ];
  int _statIndex = 0;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _reticleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && !_completed) {
          setState(() {
            _reticleFrom = _reticleTo;
            _reticleTo = Offset(
              0.18 + _rnd.nextDouble() * 0.64,
              0.30 + _rnd.nextDouble() * 0.50,
            );
            _statIndex = (_statIndex + 1) % _fakeStats.length;
          });
          _reticleCtrl.forward(from: 0);
        }
      });
    _reticleCtrl.forward();

    _hudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && !_completed) {
          setState(() {
            _stageIndex = (_stageIndex + 1) % _stages.length;
          });
          _hudCtrl.forward(from: 0);
        }
      });
    _hudCtrl.forward();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _completeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    HapticFeedback.lightImpact();

    // Escucha el resultado del scan.
    widget.scanFuture.then(
      (result) => _onDone(success: result),
      onError: (e) {
        if (e is ScanException) {
          _onDone(error: e);
        } else {
          _onDone(
            error: ScanException(code: 'error', message: e.toString()),
          );
        }
      },
    );
  }

  Future<void> _onDone({ScanResult? success, ScanException? error}) async {
    if (!mounted || _completed) return;
    setState(() {
      _completed = true;
    });
    HapticFeedback.mediumImpact();
    // Detiene loops.
    _scanLineCtrl.stop();
    _reticleCtrl.stop();
    _hudCtrl.stop();
    _glowCtrl.stop();
    await _completeCtrl.forward();
    // Pequeña pausa para que se vea el check.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop(
      FoodScanAnimationResult(success: success, error: error),
    );
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _reticleCtrl.dispose();
    _hudCtrl.dispose();
    _glowCtrl.dispose();
    _completeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Foto del plato con zoom-in lento.
          _PhotoLayer(file: widget.imageFile),

          // Oscurecedor con tinte cyan.
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.4,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // Grid HUD sutil sobre la imagen.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => CustomPaint(
                painter: _HudGridPainter(
                  pulse: _glowCtrl.value,
                  fading: _completeCtrl.value,
                ),
              ),
            ),
          ),

          // Línea de escaneo láser.
          if (!_completed)
            AnimatedBuilder(
              animation: Listenable.merge([_scanLineCtrl, _glowCtrl]),
              builder: (_, __) {
                final y = Curves.easeInOut.transform(_scanLineCtrl.value) *
                    (size.height - 4);
                final glow = 0.55 + 0.45 * _glowCtrl.value;
                return Positioned(
                  top: y,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _accent.withValues(alpha: 0),
                            _accent.withValues(alpha: 0.95 * glow),
                            Colors.white.withValues(alpha: 0.95 * glow),
                            _accent.withValues(alpha: 0.95 * glow),
                            _accent.withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.8 * glow),
                            blurRadius: 22 * glow,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Retículo HUD que salta entre puntos.
          if (!_completed)
            AnimatedBuilder(
              animation: Listenable.merge([_reticleCtrl, _glowCtrl]),
              builder: (_, __) {
                final t = Curves.easeOutCubic.transform(_reticleCtrl.value);
                final x = _lerp(_reticleFrom.dx, _reticleTo.dx, t);
                final y = _lerp(_reticleFrom.dy, _reticleTo.dy, t);
                return Positioned(
                  left: size.width * x - 40,
                  top: size.height * y - 40,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _ReticlePainter(
                          pulse: _glowCtrl.value,
                          appear: t,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Stat fake junto al retículo.
          if (!_completed)
            AnimatedBuilder(
              animation: _reticleCtrl,
              builder: (_, __) {
                final t = Curves.easeOutCubic.transform(_reticleCtrl.value);
                final x = _lerp(_reticleFrom.dx, _reticleTo.dx, t);
                final y = _lerp(_reticleFrom.dy, _reticleTo.dy, t);
                final align = x < 0.5 ? 1.0 : -1.0; // hacia la derecha o izq
                return Positioned(
                  left: (size.width * x + 50 * align) - (align < 0 ? 130 : 0),
                  top: size.height * y - 14,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          border:
                              Border.all(color: _accent.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fakeStats[_statIndex],
                          style: const TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Esquinas HUD (4 corchetes en las esquinas).
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => CustomPaint(
                painter: _CornerBracketsPainter(
                  pulse: _glowCtrl.value,
                  fading: _completeCtrl.value,
                ),
              ),
            ),
          ),

          // Texto de estado abajo + spinner.
          if (!_completed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Column(
                children: [
                  // Indicador SCANNING tipo HUD.
                  AnimatedBuilder(
                    animation: _glowCtrl,
                    builder: (_, __) {
                      final glow = 0.5 + 0.5 * _glowCtrl.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.6 * glow),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35 * glow),
                              blurRadius: 14 * glow,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accent.withValues(alpha: glow),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: glow),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SCANNING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Texto rotatorio del estado.
                  SizedBox(
                    height: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _stages[_stageIndex],
                        key: ValueKey(_stageIndex),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No cierres la app',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          // Flash blanco + check verde al terminar.
          if (_completeCtrl.value > 0)
            AnimatedBuilder(
              animation: _completeCtrl,
              builder: (_, __) {
                final t = _completeCtrl.value;
                // Flash 0..0.3 sube, 0.3..1 baja.
                final flash = t < 0.3
                    ? (t / 0.3)
                    : (1 - ((t - 0.3) / 0.7)).clamp(0.0, 1.0);
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.white.withValues(alpha: 0.85 * flash),
                        ),
                        if (t > 0.25)
                          Center(
                            child: Opacity(
                              opacity:
                                  ((t - 0.25) / 0.5).clamp(0.0, 1.0).toDouble(),
                              child: Transform.scale(
                                scale:
                                    0.6 + 0.6 * Curves.easeOutBack.transform(
                                          ((t - 0.25) / 0.6).clamp(0.0, 1.0),
                                        ),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green
                                            .withValues(alpha: 0.5),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    PhosphorIconsFill.check,
                                    color: Color(0xFF2EBE7C),
                                    size: 56,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Botón cerrar (cancelar scan).
          if (!_completed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.x,
                  color: Colors.white70,
                ),
                onPressed: () {
                  Navigator.of(context).pop(
                    FoodScanAnimationResult(
                      error: ScanException(
                        code: 'cancelled',
                        message: 'Escaneo cancelado.',
                      ),
                    ),
                  );
                },
              ),
            )
                .animate()
                .fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Foto del plato con zoom-in lento (parallax sutil).
class _PhotoLayer extends StatefulWidget {
  final File file;
  const _PhotoLayer({required this.file});

  @override
  State<_PhotoLayer> createState() => _PhotoLayerState();
}

class _PhotoLayerState extends State<_PhotoLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..forward();
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _zoom,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_zoom.value);
        return Transform.scale(
          scale: 1.05 + 0.08 * t,
          child: Image.file(
            widget.file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }
}

/// Grid HUD: líneas finas verticales y horizontales semi-transparentes.
class _HudGridPainter extends CustomPainter {
  final double pulse;
  final double fading;
  _HudGridPainter({required this.pulse, required this.fading});

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (1 - fading).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFF00BFFF)
          .withValues(alpha: 0.10 * (0.7 + 0.3 * pulse) * alpha)
      ..strokeWidth = 0.6;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter old) =>
      old.pulse != pulse || old.fading != fading;
}

/// Retículo cuadrado HUD con cruz central y esquinas.
class _ReticlePainter extends CustomPainter {
  final double pulse;
  final double appear; // 0..1 al aparecer en nueva posición

  _ReticlePainter({required this.pulse, required this.appear});

  @override
  void paint(Canvas canvas, Size size) {
    const accent = Color(0xFF00BFFF);
    final glow = 0.6 + 0.4 * pulse;
    final paint = Paint()
      ..color = accent.withValues(alpha: 0.9 * glow * appear)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final cornerLen = 16.0;
    final w = size.width;
    final h = size.height;

    // Esquinas (8 segmentos).
    final corners = [
      [Offset(0, 0), Offset(cornerLen, 0)],
      [Offset(0, 0), Offset(0, cornerLen)],
      [Offset(w, 0), Offset(w - cornerLen, 0)],
      [Offset(w, 0), Offset(w, cornerLen)],
      [Offset(0, h), Offset(cornerLen, h)],
      [Offset(0, h), Offset(0, h - cornerLen)],
      [Offset(w, h), Offset(w - cornerLen, h)],
      [Offset(w, h), Offset(w, h - cornerLen)],
    ];
    for (final c in corners) {
      canvas.drawLine(c[0], c[1], paint);
    }

    // Cruz central.
    final crossPaint = Paint()
      ..color = accent.withValues(alpha: 0.55 * glow * appear)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(w / 2 - 8, h / 2),
      Offset(w / 2 + 8, h / 2),
      crossPaint,
    );
    canvas.drawLine(
      Offset(w / 2, h / 2 - 8),
      Offset(w / 2, h / 2 + 8),
      crossPaint,
    );

    // Punto central pulsante.
    final dot = Paint()
      ..color = accent.withValues(alpha: glow * appear)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, dot);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter old) =>
      old.pulse != pulse || old.appear != appear;
}

/// Corchetes en las 4 esquinas de la pantalla (HUD frame).
class _CornerBracketsPainter extends CustomPainter {
  final double pulse;
  final double fading;
  _CornerBracketsPainter({required this.pulse, required this.fading});

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (1 - fading).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFF00BFFF)
          .withValues(alpha: 0.85 * (0.7 + 0.3 * pulse) * alpha)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const inset = 24.0;
    const len = 28.0;

    final w = size.width;
    final h = size.height;

    // Top-left.
    canvas.drawLine(
        Offset(inset, inset), Offset(inset + len, inset), paint);
    canvas.drawLine(
        Offset(inset, inset), Offset(inset, inset + len), paint);
    // Top-right.
    canvas.drawLine(
        Offset(w - inset, inset), Offset(w - inset - len, inset), paint);
    canvas.drawLine(
        Offset(w - inset, inset), Offset(w - inset, inset + len), paint);
    // Bottom-left.
    canvas.drawLine(
        Offset(inset, h - inset), Offset(inset + len, h - inset), paint);
    canvas.drawLine(
        Offset(inset, h - inset), Offset(inset, h - inset - len), paint);
    // Bottom-right.
    canvas.drawLine(Offset(w - inset, h - inset),
        Offset(w - inset - len, h - inset), paint);
    canvas.drawLine(Offset(w - inset, h - inset),
        Offset(w - inset, h - inset - len), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter old) =>
      old.pulse != pulse || old.fading != fading;
}
