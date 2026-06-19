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
  // Plazo (3/6/12 meses) — solo para objetivos de cambio físico.
  int? selectedMonths;
  late Map<String, dynamic> userData;

  // Objetivos que implican un cambio físico medible → necesitan plazo para
  // calibrar el ritmo del déficit/superávit. Mantenimiento y resistencia no.
  static bool _needsTimeframe(String? goal) =>
      goal == 'LOSE_WEIGHT' ||
      goal == 'GAIN_MUSCLE' ||
      goal == 'RECOMPOSITION' ||
      goal == 'TONE_BODY';

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
    setState(() {
      selectedGoal = goal;
      // Si el objetivo no requiere plazo, lo limpiamos.
      if (!_needsTimeframe(goal)) selectedMonths = null;
    });
  }

  bool get _canContinue =>
      selectedGoal != null &&
      (!_needsTimeframe(selectedGoal) || selectedMonths != null);

  void _onNext() {
    if (_canContinue) {
      // Mantenemos 'goal' por compat con el mapeo de signup_step_13.
      userData['goal'] = selectedGoal;
      userData['fitnessGoal'] = selectedGoal;
      userData['goalTimeframeMonths'] = selectedMonths; // null si no aplica

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

  Widget _timeframeSection() {
    return Padding(
      key: const ValueKey('timeframe'),
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: [
          const Text(
            '¿En cuánto tiempo quieres lograrlo?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajustamos tus calorías y proteína a un ritmo seguro según el plazo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          _monthCard(3, 'Más exigente', 'Ritmo rápido y seguro'),
          _monthCard(6, 'Equilibrado', 'Constante y sostenible'),
          _monthCard(12, 'Gradual', 'Suave, máxima adherencia'),
        ],
      ),
    );
  }

  Widget _monthCard(int months, String title, String subtitle) {
    final isSelected = selectedMonths == months;
    return GestureDetector(
      onTap: () => setState(() => selectedMonths = months),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentOrange
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accentOrange : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              '$months',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'meses',
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isSelected ? Colors.white70 : Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.white38,
              size: 22,
            ),
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
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _needsTimeframe(selectedGoal)
                            ? _timeframeSection()
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey('$selectedGoal-$selectedMonths'),
                          text: 'Siguiente',
                          color: AppColors.accentOrange,
                          textColor: Colors.white,
                          onPressed: _canContinue ? _onNext : null,
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
