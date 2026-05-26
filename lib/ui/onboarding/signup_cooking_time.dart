import 'package:flutter/material.dart';

import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_cooking_time';

class SignupCookingTime extends StatefulWidget {
  const SignupCookingTime({super.key});

  @override
  State<SignupCookingTime> createState() => _SignupCookingTimeState();
}

class _SignupCookingTimeState extends State<SignupCookingTime> {
  String? _cooking;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onNext() {
    if (_cooking == null) return;
    userData['cookingTimePreference'] = _cooking;
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
      backgroundAsset: 'assets/images/dieta.png',
      eyebrow: 'Tu alimentación',
      title: '¿Cuánto tiempo tienes para cocinar?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...OnboardingCatalogs.cookingTime.map(
            (o) => OnboardingChip(
              label: o.label,
              selected: _cooking == o.value,
              onTap: () => setState(() => _cooking = o.value),
              wide: true,
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _cooking != null ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {'cookingTimePreference': 'medium_15_30m'},
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
