import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/app_colors.dart';

enum AiPlanKind { routine, nutrition }

/// Pantalla full-screen que se muestra cuando una pestaña esta esperando
/// que la edge function de IA genere el plan. En vez de un spinner pelado,
/// mostramos un halo animado, mensajes rotativos y dots de progreso para
/// que el usuario sepa que la app esta trabajando, no colgada.
class AiPlanLoading extends StatefulWidget {
  const AiPlanLoading({super.key, required this.kind});

  final AiPlanKind kind;

  @override
  State<AiPlanLoading> createState() => _AiPlanLoadingState();
}

class _AiPlanLoadingState extends State<AiPlanLoading>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  Timer? _stepTimer;
  int _stepIndex = 0;

  List<String> get _steps {
    switch (widget.kind) {
      case AiPlanKind.routine:
        return const [
          'Analizando tu objetivo y nivel...',
          'Eligiendo ejercicios seguros para ti...',
          'Distribuyendo grupos musculares...',
          'Ajustando series y descansos...',
          'Últimos detalles...',
        ];
      case AiPlanKind.nutrition:
        return const [
          'Calculando tus calorías y macros...',
          'Seleccionando alimentos según tu plan...',
          'Armando comidas balanceadas...',
          'Ajustando porciones a tu objetivo...',
          'Últimos detalles...',
        ];
    }
  }

  IconData get _icon => widget.kind == AiPlanKind.routine
      ? PhosphorIconsFill.barbell
      : PhosphorIconsFill.forkKnife;

  String get _title => widget.kind == AiPlanKind.routine
      ? 'Generando tu rutina'
      : 'Generando tu plan';

  String get _subtitle => widget.kind == AiPlanKind.routine
      ? 'Estamos diseñando tu plan personalizado de entrenamiento. Toma unos segundos solo la primera vez.'
      : 'Estamos armando tu plan nutricional según tus objetivos. Toma unos segundos solo la primera vez.';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 6000), (_) {
      if (!mounted) return;
      setState(() {
        if (_stepIndex < _steps.length - 1) _stepIndex++;
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.kind == AiPlanKind.routine
        ? AppColors.ember500
        : AppColors.ember400;
    const titleColor = Color(0xFF111827);
    const subtitleColor = Color(0xFF6B7280);
    const stepColor = Color(0xFF374151);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedHaloIcon(
              pulse: _pulseCtrl,
              rotate: _rotateCtrl,
              accent: accent,
              icon: _icon,
            ),
            const SizedBox(height: 28),
            Text(
              _title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                color: subtitleColor,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(_stepIndex),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _steps[_stepIndex],
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: stepColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _ProgressDots(
              count: _steps.length,
              active: _stepIndex,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHaloIcon extends StatelessWidget {
  const _AnimatedHaloIcon({
    required this.pulse,
    required this.rotate,
    required this.accent,
    required this.icon,
  });

  final AnimationController pulse;
  final AnimationController rotate;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = Curves.easeInOut.transform(pulse.value);
              return Container(
                width: 110 + 20 * t,
                height: 110 + 20 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.08 + 0.10 * (1 - t)),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: rotate,
            builder: (_, __) {
              return Transform.rotate(
                angle: rotate.value * 2 * 3.14159,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        accent.withValues(alpha: 0.0),
                        accent.withValues(alpha: 0.0),
                        accent.withValues(alpha: 0.5),
                        accent.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.55, 0.85, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Icon(icon, size: 40, color: accent),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.count,
    required this.active,
    required this.accent,
  });

  final int count;
  final int active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i <= active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? accent
                : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Wrapper que muestra el skeleton primero y, despues de `threshold`, hace
/// un fade-in al AiPlanLoading. Sirve para que cargas rapidas (cache) muestren
/// solo el skeleton y cargas lentas (primera vez con IA) muestren la animacion
/// explicita.
class SmartAiLoading extends StatefulWidget {
  const SmartAiLoading({
    super.key,
    required this.kind,
    required this.skeleton,
    this.threshold = const Duration(milliseconds: 2500),
  });

  final AiPlanKind kind;
  final Widget skeleton;
  final Duration threshold;

  @override
  State<SmartAiLoading> createState() => _SmartAiLoadingState();
}

class _SmartAiLoadingState extends State<SmartAiLoading> {
  bool _showAi = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.threshold, () {
      if (mounted) setState(() => _showAi = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _showAi
          ? Container(
              key: const ValueKey('ai-loading'),
              child: AiPlanLoading(kind: widget.kind),
            )
          : KeyedSubtree(
              key: const ValueKey('skeleton'),
              child: widget.skeleton,
            ),
    );
  }
}
