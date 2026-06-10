import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/ai_trainer_service.dart';
import '../../services/subscription_service.dart';
import '../../services/workout_feedback_service.dart';
import 'ai_trainer_avatars.dart';

/// Bloque "Tu coach quiere saber..." que se incrusta en la pantalla de
/// celebracion post-entreno. Solo se muestra a usuarios Premium.
///
/// Cuando se conecte la edge function `post-workout-ai-response`, la respuesta
/// del coach llegara via FCM al chat del entrenador; aqui solo capturamos
/// la respuesta del usuario.
class WorkoutFeedbackPrompt extends StatefulWidget {
  const WorkoutFeedbackPrompt({super.key});

  @override
  State<WorkoutFeedbackPrompt> createState() => _WorkoutFeedbackPromptState();
}

class _WorkoutFeedbackPromptState extends State<WorkoutFeedbackPrompt> {
  AITrainerConfig? _config;
  bool _loading = true;
  bool _show = false;
  bool _submitting = false;
  bool _submitted = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final tier = await SubscriptionService.instance.currentTier();
    if (tier != SubscriptionTier.premium) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final hasToday = await WorkoutFeedbackService.instance.hasFeedbackToday();
    if (hasToday) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final config = await AITrainerService.instance.getConfig();
    if (!mounted) return;
    setState(() {
      _config = config ?? AITrainerConfig.defaults();
      _show = true;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    final id = await WorkoutFeedbackService.instance.submitFeedback(text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = id != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show) return const SizedBox.shrink();
    final config = _config!;

    if (_submitted) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            AITrainerAvatars.circle(id: config.avatarId, size: 36),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tu entrenador te respondera pronto.',
                style: TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
            Icon(PhosphorIconsFill.checkCircle,
                color: AppColors.primary, size: 20),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AITrainerAvatars.circle(id: config.avatarId, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    children: [
                      TextSpan(
                        text: '${config.trainerName} ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                        text: 'quiere saber:\nComo estuvo este entrenamiento?',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            enabled: !_submitting,
            style: const TextStyle(color: Colors.white),
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Cuentale a tu coach...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppColors.darkSurfaceElevated,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar a mi coach',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
