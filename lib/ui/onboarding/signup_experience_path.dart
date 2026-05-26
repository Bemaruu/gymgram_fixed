import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_experience_path';

class SignupExperiencePath extends StatefulWidget {
  const SignupExperiencePath({super.key});

  @override
  State<SignupExperiencePath> createState() => _SignupExperiencePathState();
}

class _SignupExperiencePathState extends State<SignupExperiencePath> {
  String? _value;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _onNext() {
    if (_value == null) return;
    userData['experiencePath'] = _value;
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
      backgroundAsset: 'assets/images/objetivo.png',
      eyebrow: 'Tú decides cómo seguir',
      title: '¿Quieres mantener tu rutina actual o crear una nueva con IA?',
      child: Column(
        children: [
          ...OnboardingCatalogs.experiencePath.map(
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
