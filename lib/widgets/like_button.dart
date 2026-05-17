import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_durations.dart';

/// Botón de like con animación "burst" de partículas al activar.
///
/// Es solo visual: la lógica de toggle la maneja el padre vía [onTap].
/// El widget se redibuja según [isLiked] y reproduce el burst cuando
/// la transición es de no-liked → liked.
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final double size;
  final Color likedColor;
  final Color unlikedColor;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    this.size = 28,
    this.likedColor = AppColors.ember400,
    this.unlikedColor = AppColors.neutral600,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  int _burstTrigger = 0;

  void _handleTap() {
    if (!widget.isLiked) {
      setState(() => _burstTrigger++);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final double radius = (widget.size + 4) * 0.7;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size + 24,
        height: widget.size + 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_burstTrigger > 0)
              ...List.generate(8, (i) {
                final angle = (i / 8) * 2 * math.pi;
                final dx = math.cos(angle) * radius;
                final dy = math.sin(angle) * radius;
                return Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.ember400,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(key: ValueKey('burst_${_burstTrigger}_$i'))
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 200.ms,
                      curve: Curves.easeOut,
                    )
                    .moveX(begin: 0, end: dx, duration: 500.ms)
                    .moveY(begin: 0, end: dy, duration: 500.ms)
                    .fadeOut(delay: 300.ms, duration: 200.ms);
              }),
            Icon(
              widget.isLiked
                  ? PhosphorIconsFill.heart
                  : PhosphorIconsRegular.heart,
              size: widget.size,
              color: widget.isLiked ? widget.likedColor : widget.unlikedColor,
            )
                .animate(key: ValueKey('heart_${widget.isLiked}'))
                .scaleXY(
                  begin: 0.8,
                  end: 1.0,
                  duration: AppDurations.base,
                  curve: Curves.elasticOut,
                ),
          ],
        ),
      ),
    );
  }
}
