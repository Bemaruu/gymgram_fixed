import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupCookingTime extends StatefulWidget {
  const SignupCookingTime({super.key});

  @override
  State<SignupCookingTime> createState() => _SignupCookingTimeState();
}

class _SignupCookingTimeState extends State<SignupCookingTime> {
  String? _value;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _onNext() {
    if (_value == null) return;
    userData['cookingTimePreference'] = _value;
    Navigator.pushNamed(context, '/signup_disliked_foods', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundAsset: 'assets/images/horario.png',
      eyebrow: 'Comida que te quede 🍳',
      title: '¿Cuánto tiempo tienes para cocinar?',
      child: Column(
        children: [
          ...OnboardingCatalogs.cookingTime.map(
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
