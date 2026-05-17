import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

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

    // Si es principiante, salta directo al siguiente paso normal (sin path).
    // Si tiene experiencia, mostramos la bifurcación.
    if (_value == 'beginner') {
      userData['experiencePath'] = 'create_ai_routine';
      Navigator.pushNamed(context, '/signup_step_5', arguments: userData);
    } else {
      Navigator.pushNamed(context, '/signup_experience_path', arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
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
