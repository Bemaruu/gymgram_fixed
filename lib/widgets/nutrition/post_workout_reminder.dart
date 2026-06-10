import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/food_service.dart';

/// Chip suave que recuerda registrar el post-entreno cuando el usuario
/// entreno hoy pero no tiene comida tipo 'post_workout'.
/// Requiere [trainedToday] true desde el caller (no inferimos el workout aqui).
class PostWorkoutReminder extends StatefulWidget {
  final bool trainedToday;
  final VoidCallback? onTap;
  const PostWorkoutReminder({super.key, required this.trainedToday, this.onTap});

  @override
  State<PostWorkoutReminder> createState() => _PostWorkoutReminderState();
}

class _PostWorkoutReminderState extends State<PostWorkoutReminder> {
  bool _show = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant PostWorkoutReminder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trainedToday != widget.trainedToday) _check();
  }

  Future<void> _check() async {
    if (!widget.trainedToday) {
      if (mounted) {
        setState(() {
          _show = false;
          _loading = false;
        });
      }
      return;
    }
    final logs = await FoodService.instance.getDailyLog(DateTime.now());
    final hasPostWorkout = logs.any((l) => l.mealType == 'post_workout');
    if (!mounted) return;
    setState(() {
      _show = !hasPostWorkout;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.ember50,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.ember200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsFill.barbell,
                  size: 14, color: AppColors.ember500),
              const SizedBox(width: 6),
              const Text(
                'Recuerda registrar tu post-entreno',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
