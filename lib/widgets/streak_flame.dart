import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../core/app_colors.dart';
import '../models/streak_model.dart';
import '../services/streak_service.dart';

/// Llama con degradado cálido y parpadeo sutil. [active] controla si arde
/// (racha viva) o se muestra apagada en gris (racha en 0).
class AnimatedFlame extends StatelessWidget {
  final double size;
  final bool active;
  final Color? inactiveColor;

  const AnimatedFlame({
    super.key,
    this.size = 22,
    this.active = true,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Icon(
        PhosphorIconsFill.flame,
        size: size,
        color: inactiveColor ?? Colors.white.withValues(alpha: 0.28),
      );
    }

    final flame = ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFFFF5252), AppColors.ember400, Color(0xFFFFC83D)],
      ).createShader(rect),
      child: Icon(PhosphorIconsFill.flame, size: size, color: Colors.white),
    );

    // Parpadeo: escala vertical + brillo muy leve, como una llama real.
    return flame
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.94, end: 1.06, duration: 700.ms, curve: Curves.easeInOut)
        .moveY(begin: 0, end: -1, duration: 700.ms, curve: Curves.easeInOut);
  }
}

/// Pastilla compacta de racha para la barra superior del feed.
/// Tócala para abrir el detalle. Si [streak] es null se carga sola.
class StreakBadge extends StatefulWidget {
  final StreakModel? streak;
  final EdgeInsetsGeometry? padding;

  const StreakBadge({super.key, this.streak, this.padding});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> {
  StreakModel? _streak;

  @override
  void initState() {
    super.initState();
    _streak = widget.streak;
    if (_streak == null) _load();
  }

  Future<void> _load() async {
    final s = await StreakService.instance.getStreak();
    if (mounted) setState(() => _streak = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _streak;
    if (s == null) {
      return const SizedBox(width: 56, height: 32);
    }
    final active = s.hasStreak;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await showStreakDetailSheet(context, initial: s);
          _load(); // refresca por si cambió mientras estaba abierto
        },
        child: Container(
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.ember400.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppColors.ember400.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedFlame(size: 18, active: active),
              const SizedBox(width: 5),
              Text(
                '${s.currentStreak}',
                style: TextStyle(
                  color: active ? Colors.white : Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Versión inline para el perfil: 🔥 Racha N · Récord M.
class StreakProfileLine extends StatelessWidget {
  final StreakModel streak;
  final Color textColor;

  const StreakProfileLine({
    super.key,
    required this.streak,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final active = streak.hasStreak;
    return GestureDetector(
      onTap: () => showStreakDetailSheet(context, initial: streak),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedFlame(
            size: 20,
            active: active,
            inactiveColor: textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(text: '${streak.currentStreak}'),
                TextSpan(
                  text: streak.currentStreak == 1 ? ' día' : ' días',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (streak.bestStreak > 0)
                  TextSpan(
                    text: '   ·   récord ${streak.bestStreak}',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carga sola la racha de un usuario y muestra [StreakProfileLine]. Se oculta
/// (SizedBox.shrink) si el usuario nunca ha entrenado. Ideal para perfiles.
class StreakInlineAuto extends StatefulWidget {
  final String? userId;
  final Color textColor;
  const StreakInlineAuto({super.key, this.userId, this.textColor = Colors.black});

  @override
  State<StreakInlineAuto> createState() => _StreakInlineAutoState();
}

class _StreakInlineAutoState extends State<StreakInlineAuto> {
  StreakModel? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StreakInlineAuto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final s = await StreakService.instance.getStreak(widget.userId);
    if (mounted) setState(() => _streak = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _streak;
    if (s == null || (s.totalWorkouts == 0 && s.bestStreak == 0)) {
      return const SizedBox.shrink();
    }
    return StreakProfileLine(streak: s, textColor: widget.textColor);
  }
}

/// Abre el detalle de la racha como bottom sheet.
Future<void> showStreakDetailSheet(
  BuildContext context, {
  String? userId,
  StreakModel? initial,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _StreakDetailSheet(userId: userId, initial: initial),
  );
}

class _StreakDetailSheet extends StatefulWidget {
  final String? userId;
  final StreakModel? initial;
  const _StreakDetailSheet({this.userId, this.initial});

  @override
  State<_StreakDetailSheet> createState() => _StreakDetailSheetState();
}

class _StreakDetailSheetState extends State<_StreakDetailSheet> {
  StreakModel? _streak;

  @override
  void initState() {
    super.initState();
    _streak = widget.initial;
    _load();
  }

  Future<void> _load() async {
    final s = await StreakService.instance.getStreak(widget.userId);
    if (mounted) setState(() => _streak = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _streak ?? StreakModel.empty;
    final active = s.hasStreak;
    final next = s.nextMilestone;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            _BigFlame(streak: s.currentStreak, active: active),
            const SizedBox(height: 10),
            Text(
              active
                  ? (s.currentStreak == 1
                      ? '1 día de racha'
                      : '${s.currentStreak} días de racha')
                  : 'Sin racha activa',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              active
                  ? 'Los días de descanso no rompen tu racha'
                  : 'Completa tu entrenamiento de hoy para encenderla',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: PhosphorIconsFill.trophy,
                    color: const Color(0xFFFFC83D),
                    value: '${s.bestStreak}',
                    label: 'Récord',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    icon: PhosphorIconsFill.barbell,
                    color: const Color(0xFF00BFFF),
                    value: '${s.totalWorkouts}',
                    label: 'Entrenamientos',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    icon: PhosphorIconsFill.medal,
                    color: AppColors.ember400,
                    value: next == null ? '✓' : '$next',
                    label: next == null ? 'Máx. hito' : 'Próx. medalla',
                  ),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 18),
              _MilestoneBar(current: s.currentStreak, target: next),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white60)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigFlame extends StatelessWidget {
  final int streak;
  final bool active;
  const _BigFlame({required this.streak, required this.active});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (active)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.ember400.withValues(alpha: 0.35),
                    AppColors.ember400.withValues(alpha: 0.0),
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.85, end: 1.05, duration: 1100.ms, curve: Curves.easeInOut),
          const AnimatedFlame(size: 72),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatBox({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MilestoneBar extends StatelessWidget {
  final int current;
  final int target;
  const _MilestoneBar({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Faltan ${target - current} ${target - current == 1 ? 'día' : 'días'} para tu próxima medalla',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.ember400),
          ),
        ),
      ],
    );
  }
}
