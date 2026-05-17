import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

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

  void _onNext() {
    if (!_privacy || !_terms) return;
    final now = DateTime.now().toIso8601String();
    userData['privacyConsentAt'] = now;
    userData['termsConsentAt'] = now;
    Navigator.pushNamed(context, '/signup_step_2', arguments: userData);
  }

  Widget _row({required bool value, required String text, required void Function(bool) onChanged}) {
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
            child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white)),
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
                    _row(
                      value: _privacy,
                      text: 'Acepto la Política de Privacidad de GymGram',
                      onChanged: (v) => setState(() => _privacy = v),
                    ),
                    _row(
                      value: _terms,
                      text: 'Acepto los Términos de Uso de GymGram',
                      onChanged: (v) => setState(() => _terms = v),
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
