import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupSessionDuration extends StatefulWidget {
  const SignupSessionDuration({super.key});

  @override
  State<SignupSessionDuration> createState() => _SignupSessionDurationState();
}

class _SignupSessionDurationState extends State<SignupSessionDuration> {
  String? _value;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _onNext() {
    if (_value == null) return;
    userData['sessionDurationMinutes'] = int.parse(_value!);
    Navigator.pushNamed(context, '/signup_step_12', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundAsset: 'assets/images/hora.png',
      eyebrow: 'Tu tiempo importa ⏱️',
      title: '¿Cuánto puedes dedicar a cada entrenamiento?',
      child: Column(
        children: [
          ...OnboardingCatalogs.sessionDuration.map(
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
