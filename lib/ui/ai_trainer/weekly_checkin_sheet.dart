import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../services/ai_trainer_service.dart';
import '../../services/subscription_service.dart';
import '../../services/weekly_checkin_service.dart';
import 'ai_trainer_avatars.dart';

/// Sheet que pregunta al usuario como estuvo su semana. Se muestra automaticamente
/// el viernes/sabado si es Plus/Premium y no ha respondido esta semana.
class WeeklyCheckinSheet extends StatefulWidget {
  const WeeklyCheckinSheet({super.key});

  /// Muestra el sheet si corresponde (viernes/sabado, tier Plus/Premium,
  /// sin check-in esta semana). Retorna true si se mostro.
  static Future<bool> maybeShow(BuildContext context) async {
    final tier = await SubscriptionService.instance.currentTier();
    if (tier == SubscriptionTier.free) return false;
    final wd = DateTime.now().weekday; // 5=fri, 6=sat, 7=sun
    if (wd < 5) return false;
    final already =
        await WeeklyCheckinService.instance.hasCheckedInThisWeek();
    if (already) return false;
    if (!context.mounted) return false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const WeeklyCheckinSheet(),
    );
    return true;
  }

  @override
  State<WeeklyCheckinSheet> createState() => _WeeklyCheckinSheetState();
}

class _WeeklyCheckinSheetState extends State<WeeklyCheckinSheet> {
  final _controller = TextEditingController();
  AITrainerConfig? _config;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final c = await AITrainerService.instance.getConfig();
    if (!mounted) return;
    setState(() => _config = c ?? AITrainerConfig.defaults());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    final ok = await WeeklyCheckinService.instance.submitCheckin(text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar. Intenta de nuevo.')),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu reporte mensual lo tendra en cuenta.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config ?? AITrainerConfig.defaults();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AITrainerAvatars.circle(id: config.avatarId, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      children: [
                        TextSpan(
                          text: '${config.trainerName}\n',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text: 'Como estuvo tu semana de entrenamiento?',
                          style: TextStyle(color: Colors.white70, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              style: const TextStyle(color: Colors.white),
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cuentale a tu coach...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppColors.darkSurfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enviar a mi coach',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
