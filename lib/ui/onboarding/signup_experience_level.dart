import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_experience_level';

class SignupExperienceLevel extends StatefulWidget {
  const SignupExperienceLevel({super.key});

  @override
  State<SignupExperienceLevel> createState() => _SignupExperienceLevelState();
}

class _SignupExperienceLevelState extends State<SignupExperienceLevel> {
  String? _value;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _onNext() {
    if (_value == null) return;
    userData['trainingLevel'] = _value;
    // Si es principiante, fijamos el path por defecto y la pantalla siguiente
    // se salta automáticamente vía OnboardingFlow.
    if (_value == 'beginner') {
      userData['experiencePath'] = 'create_ai_routine';
    }
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = OnboardingFlow.progressFor(_route, userData);
    return OnboardingScaffold(
      step: progress.step,
      total: progress.total,
      backgroundAsset: 'assets/images/ocupacion.png',
      eyebrow: 'Adaptamos todo a ti',
      title: '¿Cuánto tiempo llevas entrenando?',
      child: Column(
        children: [
          ...OnboardingCatalogs.trainingLevel.map(
            (o) => OnboardingChip(
              label: o.label,
              selected: _value == o.value,
              onTap: () => setState(() => _value = o.value),
              wide: true,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Siguiente',
            onPressed: _value != null ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
