import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_split';

class SignupSplit extends StatefulWidget {
  const SignupSplit({super.key});

  @override
  State<SignupSplit> createState() => _SignupSplitState();
}

class _SignupSplitState extends State<SignupSplit> {
  String? _split;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onNext() {
    if (_split == null) return;
    userData['routineSplitPreference'] = _split;
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
      eyebrow: 'Tu disponibilidad',
      title: '¿Qué tipo de rutina prefieres?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.routineSplit
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _split == o.value,
                      onTap: () => setState(() => _split = o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _split != null ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {'routineSplitPreference': 'full_body'},
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
