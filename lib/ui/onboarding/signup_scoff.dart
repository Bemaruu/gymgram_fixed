import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_scoff';

class SignupScoff extends StatefulWidget {
  const SignupScoff({super.key});

  @override
  State<SignupScoff> createState() => _SignupScoffState();
}

class _SignupScoffState extends State<SignupScoff> {
  late Map<String, dynamic> userData;

  static const _questions = <Map<String, String>>[
    {
      'key': 's',
      'q':
          '¿Te provocas el vómito porque te sientes incómodo/a con la comida?',
    },
    {
      'key': 'c',
      'q': '¿Te preocupa haber perdido el control sobre lo que comes?',
    },
    {
      'key': 'o',
      'q': '¿Has perdido más de 6 kg en los últimos 3 meses?',
    },
    {
      'key': 'f',
      'q':
          '¿Crees que estás gordo/a cuando otros dicen que estás delgado/a?',
    },
    {
      'key': 'f2',
      'q': '¿Dirías que la comida domina tu vida?',
    },
  ];

  final Map<String, bool?> _answers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  bool get _canContinue =>
      _questions.every((q) => _answers[q['key']!] != null);

  void _onNext() {
    if (!_canContinue) return;
    final score = _answers.values.where((v) => v == true).length;
    userData['scoffScore'] = score;
    userData['eatingDisorderRisk'] = score >= 2;

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
      eyebrow: 'Tu bienestar',
      title: 'Cuéntanos un poco más sobre tu relación con la comida',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Esto es confidencial y nos ayuda a cuidar tu bienestar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black54,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          ..._questions.map((q) => _YesNoQuestion(
                question: q['q']!,
                value: _answers[q['key']!],
                onChanged: (v) => setState(() => _answers[q['key']!] = v),
              )),
          const SizedBox(height: 18),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _canContinue ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}

class _YesNoQuestion extends StatelessWidget {
  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _YesNoQuestion({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PillChoice(
                    label: 'Sí',
                    selected: value == true,
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillChoice(
                    label: 'No',
                    selected: value == false,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.lightGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.black12,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
