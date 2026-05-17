import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/custom_button.dart';

class SignupStep8 extends StatefulWidget {
  const SignupStep8({super.key});

  @override
  State<SignupStep8> createState() => _SignupStep8State();
}

class _SignupStep8State extends State<SignupStep8> {
  final TextEditingController _currentWeightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();

  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = ModalRoute.of(context)!.settings.arguments as Map;
    // Map<String,dynamic>.from convierte el tipo real (no solo cast),
    // permitiendo guardar double/List/bool además de String.
    userData = Map<String, dynamic>.from(raw);
  }

  double? _parseNum(String raw) {
    // Acepta coma decimal (típica en español) y punto.
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  void _showError(String msg) {
    // Cierra el teclado primero para que el snackbar no quede tapado.
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
    final currentWeight = _parseNum(_currentWeightController.text);
    final height = _parseNum(_heightController.text);
    final targetWeight = _parseNum(_targetWeightController.text);

    if (currentWeight == null || height == null || targetWeight == null) {
      _showError('Completa peso, estatura y peso objetivo con números válidos');
      return;
    }
    if (currentWeight < 30 || currentWeight > 300) {
      _showError('El peso debe estar entre 30 y 300 kg');
      return;
    }
    if (height < 100 || height > 250) {
      _showError('La estatura debe estar entre 100 y 250 cm');
      return;
    }
    if (targetWeight < 30 || targetWeight > 300) {
      _showError('El peso objetivo debe estar entre 30 y 300 kg');
      return;
    }

    final heightInMeters = height / 100;
    final bmi = currentWeight / (heightInMeters * heightInMeters);

    // Guardamos como número, no como string, para evitar parseos posteriores.
    userData['currentWeight'] = currentWeight;
    userData['weight'] = currentWeight;
    userData['height'] = height;
    userData['targetWeight'] = targetWeight;
    userData['bmi'] = bmi;

    Navigator.pushNamed(
      context,
      '/signup_step_4',
      arguments: userData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/balanza.png',
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '¡Ya casi terminamos!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '¿Cuánto pesas y mides?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInputField(
                        controller: _currentWeightController,
                        hint: 'Peso actual (kg)',
                        icon: Icons.monitor_weight,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _heightController,
                        hint: 'Estatura (cm)',
                        icon: Icons.height,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _targetWeightController,
                        hint: 'Peso objetivo (kg)',
                        icon: Icons.fitness_center,
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: 'Siguiente',
                        onPressed: _onNext,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Volver',
                          textAlign: TextAlign.center,
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Acepta dígitos y un único separador decimal (punto o coma).
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
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
