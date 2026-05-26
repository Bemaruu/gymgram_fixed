import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_body_metrics';

class SignupBodyMetrics extends StatefulWidget {
  const SignupBodyMetrics({super.key});

  @override
  State<SignupBodyMetrics> createState() => _SignupBodyMetricsState();
}

class _SignupBodyMetricsState extends State<SignupBodyMetrics> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _showError(String msg) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onNext() {
    final weight = _parseNum(_weightCtrl.text);
    final height = _parseNum(_heightCtrl.text);
    final target = _parseNum(_targetCtrl.text);
    if (weight == null || height == null || target == null) {
      _showError('Completa peso, estatura y peso objetivo con números válidos');
      return;
    }
    if (weight < 30 || weight > 300) {
      _showError('El peso debe estar entre 30 y 300 kg');
      return;
    }
    if (height < 100 || height > 250) {
      _showError('La estatura debe estar entre 100 y 250 cm');
      return;
    }
    if (target < 30 || target > 300) {
      _showError('El peso objetivo debe estar entre 30 y 300 kg');
      return;
    }

    final heightM = height / 100;
    userData['currentWeight'] = weight;
    userData['weight'] = weight;
    userData['height'] = height;
    userData['targetWeight'] = target;
    userData['bmi'] = weight / (heightM * heightM);

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
      backgroundAsset: 'assets/images/balanza.png',
      eyebrow: 'Sobre ti',
      title: '¿Cuánto pesas y mides?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _input(_weightCtrl, 'Peso actual (kg)', Icons.monitor_weight),
          const SizedBox(height: 12),
          _input(_heightCtrl, 'Estatura (cm)', Icons.height),
          const SizedBox(height: 12),
          _input(_targetCtrl, 'Peso objetivo (kg)', Icons.fitness_center),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _onNext,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        prefixIcon: Icon(icon, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
