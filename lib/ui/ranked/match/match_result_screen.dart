import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';

/// Pantalla de resultado del duelo 1v1 — cinemática completa.
class MatchResultScreen extends StatefulWidget {
  final MatchState state;
  final String mySlot; // 'a' | 'b'
  final VoidCallback? onRematch;

  const MatchResultScreen({
    super.key,
    required this.state,
    required this.mySlot,
    this.onRematch,
  });

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _raysCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _bgCtrl;

  bool get _iWon =>
      widget.state.match.winnerId != null &&
      ((widget.mySlot == 'a' &&
              widget.state.match.winnerId == widget.state.match.playerA) ||
          (widget.mySlot == 'b' &&
              widget.state.match.winnerId == widget.state.match.playerB));

  int get _myWins =>
      widget.mySlot == 'a' ? widget.state.match.winsA : widget.state.match.winsB;
  int get _rivalWins =>
      widget.mySlot == 'a' ? widget.state.match.winsB : widget.state.match.winsA;
  int get _myDelta => (widget.mySlot == 'a'
          ? widget.state.match.rpDeltaA
          : widget.state.match.rpDeltaB) ??
      0;

  MatchPlayer get _rival =>
      widget.mySlot == 'a' ? widget.state.playerB : widget.state.playerA;

  @override
  void initState() {
    super.initState();
    _raysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Secuencia de haptics tipo cinemática.
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _iWon
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.selectionClick();
      }
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) HapticFeedback.lightImpact();
    });
  }

  @override
  void dispose() {
    _raysCtrl.dispose();
    _glowCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final won = _iWon;
    final abandoned = widget.state.match.status == MatchStatus.abandoned;
    final size = MediaQuery.of(context).size;
    final accent = won ? AppColors.gold : AppColors.danger;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo oscuro animado.
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_bgCtrl.value);
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      accent.withValues(alpha: 0.18 * t),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),
          // Rayos radiales (CustomPainter).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_raysCtrl, _glowCtrl]),
              builder: (_, __) {
                return CustomPaint(
                  painter: _RaysPainter(
                    progress: Curves.easeOutCubic.transform(_raysCtrl.value),
                    pulse: _glowCtrl.value,
                    color: accent,
                    intensity: won ? 1.0 : 0.55,
                  ),
                );
              },
            ),
          ),
          // Partículas de chispas en victoria.
          if (won)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _raysCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _SparksPainter(
                      progress: _raysCtrl.value,
                      seed: widget.state.match.id.hashCode,
                    ),
                  ),
                ),
              ),
            ),
          // Contenido scrollable.
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: size.height * 0.04),
                  _buildHero(won, abandoned),
                  const SizedBox(height: 20),
                  _buildScoreboard(won),
                  const SizedBox(height: 24),
                  _buildRpCinematic(won),
                  const SizedBox(height: 28),
                  _sectionTitle('Resumen del duelo')
                      .animate()
                      .fadeIn(delay: 2800.ms, duration: 400.ms)
                      .slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 12),
                  ..._buildRecap(),
                  const SizedBox(height: 28),
                  _buildActions(context)
                      .animate()
                      .fadeIn(delay: 3600.ms, duration: 500.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool won, bool abandoned) {
    return Column(
      children: [
        // Icono con glow pulsante.
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, child) {
            final pulse = 0.55 + 0.45 * _glowCtrl.value;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (won ? AppColors.gold : AppColors.danger)
                        .withValues(alpha: 0.55 * pulse),
                    blurRadius: 50 * pulse,
                    spreadRadius: 4 * pulse,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Icon(
            won ? PhosphorIconsFill.crown : PhosphorIconsFill.shield,
            size: 70,
            color: won ? AppColors.gold : Colors.white.withValues(alpha: 0.5),
          ),
        )
            .animate()
            .scale(
              duration: 800.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.1, 0.1),
              end: const Offset(1, 1),
            )
            .then()
            .shake(hz: won ? 3 : 0, offset: const Offset(2, 0), duration: 400.ms),
        const SizedBox(height: 14),
        // Título VICTORIA / DERROTA con shimmer.
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: won
                ? [Colors.white, AppColors.gold, AppColors.accentOrange]
                : [Colors.white70, Colors.white24],
          ).createShader(rect),
          child: Text(
            won ? 'VICTORIA' : 'DERROTA',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              height: 1,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack)
            .then(delay: 100.ms)
            .shimmer(
              duration: 1400.ms,
              color: won ? AppColors.gold : Colors.white,
            ),
        const SizedBox(height: 6),
        Text(
          abandoned
              ? (won
                  ? '@${_rival.username} abandonó el duelo'
                  : 'Abandonaste el duelo')
              : 'Marcador final',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildScoreboard(bool won) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scoreNumber(_myWins, won ? AppColors.primary : Colors.white70, won),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '·',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 36,
                fontWeight: FontWeight.w900),
          ),
        ),
        _scoreNumber(_rivalWins,
            !won ? AppColors.accentOrange : Colors.white70, !won),
      ],
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _scoreNumber(int value, Color color, bool emphasis) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        v.round().toString(),
        style: TextStyle(
          color: color,
          fontSize: emphasis ? 44 : 36,
          fontWeight: FontWeight.w900,
          shadows: emphasis
              ? [
                  Shadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildRpCinematic(bool won) {
    final delta = _myDelta;
    final positive = delta >= 0;
    final color = positive ? AppColors.success : AppColors.danger;
    final sign = positive ? '+' : '−';
    final absDelta = delta.abs();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            positive ? 'Has ganado' : 'Has perdido',
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ).animate().fadeIn(delay: 1700.ms, duration: 300.ms),
          const SizedBox(height: 8),
          // Counter cinemático del delta.
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, child) {
              final pulse = 0.6 + 0.4 * _glowCtrl.value;
              return Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6 * pulse),
                      blurRadius: 40 * pulse,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  sign,
                  style: TextStyle(
                    color: color,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: absDelta.toDouble()),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    v.round().toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.8),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'RP',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            positive
                ? '¡Sigue subiendo, leyenda!'
                : 'La revancha está ahí. Vuelve más fuerte.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: 2600.ms, duration: 400.ms),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 1500.ms, duration: 500.ms)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        )
        .then(delay: 200.ms)
        .shake(
          hz: positive ? 0 : 4,
          offset: const Offset(3, 0),
          duration: 350.ms,
        );
  }

  List<Widget> _buildRecap() {
    final rounds =
        widget.state.rounds.where((r) => r.bothSubmitted).toList();
    return List.generate(rounds.length, (i) {
      return _recapRow(rounds[i])
          .animate()
          .fadeIn(
            delay: Duration(milliseconds: 3000 + i * 120),
            duration: 400.ms,
          )
          .slideX(begin: 0.1, end: 0);
    });
  }

  Widget _recapRow(MatchRound r) {
    final myScore = widget.mySlot == 'a' ? r.scoreA : r.scoreB;
    final rivalScore = widget.mySlot == 'a' ? r.scoreB : r.scoreA;
    final myWeight = widget.mySlot == 'a' ? r.weightA : r.weightB;
    final myReps = widget.mySlot == 'a' ? r.repsA : r.repsB;
    final rivalWeight = widget.mySlot == 'a' ? r.weightB : r.weightA;
    final rivalReps = widget.mySlot == 'a' ? r.repsB : r.repsA;
    final iWonRound = r.roundWinner == widget.mySlot;
    final tie = r.roundWinner == 'tie';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tie
              ? Colors.white12
              : (iWonRound
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.danger.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'R${r.roundNumber}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.state.exerciseNameFor(r),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${_fmt(myWeight)}×${myReps ?? '-'} (${myScore?.toStringAsFixed(0) ?? '-'})',
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 11),
                    ),
                    const Text('  vs  ',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text(
                      '${_fmt(rivalWeight)}×${rivalReps ?? '-'} (${rivalScore?.toStringAsFixed(0) ?? '-'})',
                      style: const TextStyle(
                          color: AppColors.accentOrange, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            tie
                ? PhosphorIconsRegular.equals
                : (iWonRound
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsFill.xCircle),
            color: tie
                ? Colors.white38
                : (iWonRound ? AppColors.success : AppColors.danger),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _fmt(double? v) {
    if (v == null) return '-';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (widget.onRematch != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                widget.onRematch!();
              },
              icon: const Icon(PhosphorIconsFill.sword, size: 18),
              label: const Text('Revancha'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: AppColors.darkBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Volver a Ranked'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.gold, AppColors.accentOrange],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            t,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      );
}

/// Rayos radiales que se expanden desde el centro (sunburst).
class _RaysPainter extends CustomPainter {
  final double progress; // 0..1 expansión inicial
  final double pulse; // 0..1 pulso continuo
  final Color color;
  final double intensity;

  _RaysPainter({
    required this.progress,
    required this.pulse,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.30);
    final maxR = size.longestSide * 1.2;
    final rays = 18;

    final basePaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withValues(
        alpha: 0.18 * progress * intensity * (0.7 + 0.3 * pulse),
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    final rot = pulse * 0.18; // rotación lenta
    canvas.rotate(rot);
    for (var i = 0; i < rays; i++) {
      final a = (i / rays) * math.pi * 2;
      final width = 22.0 + 8 * math.sin(i * 1.3 + pulse * 6);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(
          math.cos(a - 0.04) * maxR * progress,
          math.sin(a - 0.04) * maxR * progress,
        )
        ..lineTo(
          math.cos(a + 0.04) * maxR * progress,
          math.sin(a + 0.04) * maxR * progress,
        )
        ..close();
      basePaint.strokeWidth = width;
      canvas.drawPath(path, basePaint);
    }
    canvas.restore();

    // Halo central.
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.55 * progress * intensity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxR * 0.5));
    canvas.drawCircle(center, maxR * 0.5 * progress, halo);
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.color != color ||
      old.intensity != intensity;
}

/// Chispas doradas que vuelan en victoria.
class _SparksPainter extends CustomPainter {
  final double progress; // 0..1
  final int seed;

  _SparksPainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rnd = math.Random(seed);
    final center = Offset(size.width / 2, size.height * 0.30);
    final count = 28;
    final t = Curves.easeOutCubic.transform(progress);

    for (var i = 0; i < count; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final dist = (80 + rnd.nextDouble() * 260) * t;
      final dx = center.dx + math.cos(a) * dist;
      final dy = center.dy + math.sin(a) * dist + (40 * t * t);
      final r = 2.0 + rnd.nextDouble() * 2.5;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = (rnd.nextBool() ? AppColors.gold : AppColors.accentOrange)
            .withValues(alpha: alpha)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparksPainter old) =>
      old.progress != progress || old.seed != seed;
}
