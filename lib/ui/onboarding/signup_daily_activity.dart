import 'package:flutter/material.dart';

import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_daily_activity';

class SignupDailyActivity extends StatefulWidget {
  const SignupDailyActivity({super.key});

  @override
  State<SignupDailyActivity> createState() => _SignupDailyActivityState();
}

class _SignupDailyActivityState extends State<SignupDailyActivity> {
  String? _activity;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onNext() {
    if (_activity == null) return;
    userData['dailyActivityLevel'] = _activity;
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
      backgroundAsset: 'assets/images/dias.png',
      eyebrow: 'Tu día a día',
      title: '¿Cómo es tu actividad fuera del gimnasio?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...OnboardingCatalogs.dailyActivity.map(
            (o) => OnboardingChip(
              label: o.label,
              selected: _activity == o.value,
              onTap: () => setState(() => _activity = o.value),
              wide: true,
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _activity != null ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {'dailyActivityLevel': 'moderate'},
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
