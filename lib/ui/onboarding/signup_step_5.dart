import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupStep5 extends StatefulWidget {
  const SignupStep5({super.key});

  @override
  State<SignupStep5> createState() => _SignupStep5State();
}

class _SignupStep5State extends State<SignupStep5> with TickerProviderStateMixin {
  // Single-select: el modelo de IA necesita un único objetivo principal.
  String? selectedGoal;
  late Map<String, dynamic> userData;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _selectGoal(String goal) {
    setState(() => selectedGoal = goal);
  }

  void _onNext() {
    if (selectedGoal != null) {
      // Mantenemos 'goal' por compat con el mapeo de signup_step_13.
      userData['goal'] = selectedGoal;
      userData['fitnessGoal'] = selectedGoal;

      final next = OnboardingFlow.nextRoute('/signup_step_5', userData);
      if (next != null) {
        Navigator.pushNamed(context, next, arguments: userData);
      }
    }
  }

  Widget goalButton(String label, IconData icon, String value, Color color) {
    final isSelected = selectedGoal == value;
    return GestureDetector(
      onTap: () => _selectGoal(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
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
            Icon(icon, size: 28, color: isSelected ? Colors.white : color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/objetivo.png',
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: Colors.black.withAlpha(60)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(builder: (_) {
                        final p = OnboardingFlow.progressFor('/signup_step_5', userData);
                        return OnboardingProgress(step: p.step, total: p.total);
                      }),
                      const Text(
                        '¡Vamos por tu mejor versión!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '¿Cuál es tu objetivo principal?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      goalButton('Perder grasa', Icons.local_fire_department, 'LOSE_WEIGHT', AppColors.primary),
                      goalButton('Ganar masa muscular', Icons.fitness_center, 'GAIN_MUSCLE', AppColors.accentOrange),
                      goalButton('Recomposición', Icons.swap_horiz, 'RECOMPOSITION', AppColors.darkBlue),
                      goalButton('Mantenerme sano', Icons.favorite, 'MAINTAIN', AppColors.primary),
                      goalButton('Mejorar resistencia', Icons.directions_run, 'IMPROVE_ENDURANCE', AppColors.accentOrange),
                      goalButton('Tonificar', Icons.self_improvement, 'TONE_BODY', AppColors.darkBlue),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey(selectedGoal),
                          text: 'Siguiente',
                          color: AppColors.accentOrange,
                          textColor: Colors.white,
                          onPressed: selectedGoal != null ? _onNext : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Volver',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
