import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_health_gate';

class SignupHealthGate extends StatefulWidget {
  const SignupHealthGate({super.key});

  @override
  State<SignupHealthGate> createState() => _SignupHealthGateState();
}

class _SignupHealthGateState extends State<SignupHealthGate> {
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onAnswer(bool hasIssue) {
    userData['hasHealthIssue'] = hasIssue;
    if (!hasIssue) {
      userData['injuries'] = ['none'];
      userData['requiresMedicalClearance'] = false;
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
      backgroundAsset: 'assets/images/dias.png',
      eyebrow: 'Tu salud',
      title:
          '¿Tienes alguna lesión activa o condición médica que afecte tu entrenamiento?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _BigChoiceButton(
            label: 'Sí, tengo algo',
            selected: false,
            onTap: () => _onAnswer(true),
          ),
          const SizedBox(height: 12),
          _BigChoiceButton(
            label: 'No, ninguna',
            selected: false,
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
  final bool selected;
  final VoidCallback onTap;

  const _BigChoiceButton({
    required this.label,
    required this.selected,
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
          color: selected ? AppColors.primary : Colors.white,
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}
