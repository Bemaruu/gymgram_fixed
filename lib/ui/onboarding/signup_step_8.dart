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
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  void _onNext() {
    final currentWeight = double.tryParse(_currentWeightController.text);
    final height = double.tryParse(_heightController.text);
    final targetWeight = double.tryParse(_targetWeightController.text);

    if (currentWeight != null && height != null && targetWeight != null) {
      final heightInMeters = height / 100;
      final bmi = currentWeight / (heightInMeters * heightInMeters);
      print('IMC: $bmi');

      userData['currentWeight'] = currentWeight.toString();
      userData['height'] = height.toString();
      userData['targetWeight'] = targetWeight.toString();
      userData['bmi'] = bmi.toStringAsFixed(2);


      Navigator.pushNamed(
        context,
        '/signup_step_9',
        arguments: userData,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos con números válidos')),
      );
    }
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
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.85),
        prefixIcon: Icon(icon, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
