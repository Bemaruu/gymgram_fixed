import 'package:flutter/material.dart';

import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_diet_meals';

class SignupDietMeals extends StatefulWidget {
  const SignupDietMeals({super.key});

  @override
  State<SignupDietMeals> createState() => _SignupDietMealsState();
}

class _SignupDietMealsState extends State<SignupDietMeals> {
  String? _diet;
  String? _meals;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  bool get _canNext => _diet != null && _meals != null;

  void _onNext() {
    if (!_canNext) return;
    userData['foodPreferences'] = [_diet];
    userData['mealsPerDay'] = _meals;
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
      title: 'Tipo de dieta y cuántas comidas haces',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Tipo de dieta'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.diet
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _diet == o.value,
                      onTap: () => setState(() => _diet = o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _label('¿Cuántas veces al día comes?'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.mealsPerDay
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _meals == o.value,
                      onTap: () => setState(() => _meals = o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _canNext ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {
              'foodPreferences': ['no_preference'],
              'mealsPerDay': '3',
            },
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2))],
        ),
      );
}
