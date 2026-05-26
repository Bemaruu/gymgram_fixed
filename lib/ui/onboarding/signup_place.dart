import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_place';

class SignupPlace extends StatefulWidget {
  const SignupPlace({super.key});

  @override
  State<SignupPlace> createState() => _SignupPlaceState();
}

class _SignupPlaceState extends State<SignupPlace> {
  String? _place;
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onNext() {
    if (_place == null) return;
    userData['trainingPlace'] = _place;
    userData['trainingLocation'] = _place;
    // Si elige GYM, asumimos gym completo y saltamos la pantalla de equipo.
    if (_place == 'GYM') {
      userData['equipmentAvailable'] = ['full_gym'];
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
      backgroundAsset: 'assets/images/lugar.png',
      eyebrow: 'Tu entrenamiento',
      title: '¿Dónde entrenas?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _placeButton('En casa', Icons.home, 'HOME', AppColors.primary),
          _placeButton('Gimnasio', Icons.fitness_center, 'GYM', AppColors.accentOrange),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _place != null ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _placeButton(String label, IconData icon, String value, Color color) {
    final selected = _place == value;
    return GestureDetector(
      onTap: () => setState(() => _place = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: selected ? Colors.white : color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
