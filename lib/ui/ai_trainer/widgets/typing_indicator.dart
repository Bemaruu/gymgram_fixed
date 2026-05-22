import 'package:flutter/material.dart';

/// Tres puntos animados estilo iMessage que se usan como "typing indicator"
/// mientras se espera la respuesta del coach IA o del otro usuario en un DM.
class TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const TypingDots({
    super.key,
    this.color = Colors.white70,
    this.size = 6,
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_ctrl.value + i * 0.18) % 1.0);
            final scale = t < 0.5 ? 0.6 + t : 1.6 - t;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.1),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
