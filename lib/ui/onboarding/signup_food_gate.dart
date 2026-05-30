import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_food_gate';

class SignupFoodGate extends StatefulWidget {
  const SignupFoodGate({super.key});

  @override
  State<SignupFoodGate> createState() => _SignupFoodGateState();
}

class _SignupFoodGateState extends State<SignupFoodGate> {
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onAnswer(bool hasRestriction) {
    userData['hasFoodRestriction'] = hasRestriction;
    if (!hasRestriction) {
      userData['dietaryRestrictions'] = ['none'];
      userData['eatingDisorderRisk'] = false;
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
      backgroundAsset: 'assets/images/dieta.png',
      eyebrow: 'Tu alimentación',
      title: '¿Tienes alergias, intolerancias o restricciones alimentarias?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _BigChoiceButton(
            label: 'Sí, tengo algo',
            onTap: () => _onAnswer(true),
          ),
          const SizedBox(height: 12),
          _BigChoiceButton(
            label: 'No, ninguna',
            onTap: () => _onAnswer(false),
          ),
          const SizedBox(height: 20),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}

class _BigChoiceButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BigChoiceButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
