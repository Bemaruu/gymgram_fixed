import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';

/// Modal de aceptación del disclaimer de IA. Se muestra UNA SOLA VEZ
/// la primera vez que el usuario entra a la pantalla de rutina o
/// alimentación. Al aceptar, persiste `profiles.disclaimer_accepted_at`.
class FirstUseDisclaimerModal extends StatefulWidget {
  const FirstUseDisclaimerModal({super.key});

  static const String _bodyText =
      'Tu rutina y plan de comidas son recomendaciones generadas por IA '
      'sobre un catálogo validado profesionalmente. No reemplazan la opinión '
      'de un médico, kinesiólogo o nutricionista. Puedes modificar ejercicios, '
      'comidas, lesiones o restricciones desde tu perfil cuando quieras. Si '
      'sientes dolor o incomodidad, detente y consulta a un profesional.';

  /// Comprueba si el usuario ya aceptó el disclaimer. Si no, muestra el modal
  /// y persiste la aceptación. Llamar desde initState (postFrameCallback) de
  /// rutina/alimentación.
  static Future<void> ensureAcceptedFor(BuildContext context) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final row = await client
          .from('profiles')
          .select('disclaimer_accepted_at')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;
      if (row['disclaimer_accepted_at'] != null) return;
    } catch (_) {
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstUseDisclaimerModal(),
    );

    try {
      await client
          .from('profiles')
          .update({'disclaimer_accepted_at': DateTime.now().toIso8601String()})
          .eq('id', uid);
    } catch (_) {
      // Silencioso. Si falla, el modal volverá a aparecer la próxima sesión.
    }
  }

  @override
  State<FirstUseDisclaimerModal> createState() =>
      _FirstUseDisclaimerModalState();
}

class _FirstUseDisclaimerModalState extends State<FirstUseDisclaimerModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.darkSurfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Antes de empezar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              FirstUseDisclaimerModal._bodyText,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
