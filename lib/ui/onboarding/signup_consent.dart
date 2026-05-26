import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../../services/analytics_service.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupConsent extends StatefulWidget {
  const SignupConsent({super.key});

  @override
  State<SignupConsent> createState() => _SignupConsentState();
}

class _SignupConsentState extends State<SignupConsent> {
  bool _privacy = false;
  bool _terms = false;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  Future<void> _onNext() async {
    if (!_privacy || !_terms) return;
    final now = DateTime.now().toIso8601String();
    userData['privacyConsentAt'] = now;
    userData['termsConsentAt'] = now;
    // El consentimiento de la Política de Privacidad incluye el uso de
    // Mixpanel para analítica de comportamiento (sección 16 privacy.md).
    await AnalyticsService.instance.enableAnalytics();
    if (!mounted) return;
    final next = OnboardingFlow.nextRoute('/signup_consent', userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  TextSpan _legalLink(String label, String route) {
    return TextSpan(
      text: label,
      style: const TextStyle(
        color: AppColors.primary,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => Navigator.pushNamed(context, route),
    );
  }

  Widget _consentRow({
    required bool value,
    required void Function(bool) onChanged,
    required String prefix,
    required String linkLabel,
    required String linkRoute,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.white),
                children: [
                  TextSpan(text: prefix),
                  _legalLink(linkLabel, linkRoute),
                  const TextSpan(text: ' de GymGram'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _privacy && _terms;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/inicio.png', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withAlpha(80)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(builder: (_) {
                      final p = OnboardingFlow.progressFor('/signup_consent', userData);
                      return OnboardingProgress(step: p.step, total: p.total);
                    }),
                    const Text(
                      'Antes de empezar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tus datos están protegidos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GymGram usa tu información sólo para personalizar tu experiencia. Nunca la compartimos con terceros sin tu permiso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    _consentRow(
                      value: _privacy,
                      onChanged: (v) => setState(() => _privacy = v),
                      prefix: 'Acepto la ',
                      linkLabel: 'Política de Privacidad',
                      linkRoute: '/legal/privacy',
                    ),
                    _consentRow(
                      value: _terms,
                      onChanged: (v) => setState(() => _terms = v),
                      prefix: 'Acepto los ',
                      linkLabel: 'Términos de Uso',
                      linkRoute: '/legal/terms',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Beta cerrada: la app está en pruebas, puede contener errores y los datos podrían perderse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Continuar',
                      onPressed: canNext ? _onNext : null,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Volver',
                        style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
