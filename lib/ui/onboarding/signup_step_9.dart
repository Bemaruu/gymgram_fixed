import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

class SignupStep9 extends StatefulWidget {
  const SignupStep9({super.key});

  @override
  State<SignupStep9> createState() => _SignupStep9State();
}

class _SignupStep9State extends State<SignupStep9> with TickerProviderStateMixin {
  final Set<String> selectedDiets = {};
  late Map<String, dynamic> userData;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> dietOptions = [
    {'label': 'Normal', 'value': 'normal'},
    {'label': 'Vegetariana', 'value': 'vegetariana'},
    {'label': 'Vegana', 'value': 'vegana'},
    {'label': 'Alta en proteínas', 'value': 'proteica'},
    {'label': 'Baja en carbohidratos', 'value': 'lowcarb'},
    {'label': 'Sin preferencia', 'value': 'libre'},
  ];

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

  void _toggleDiet(String value) {
    setState(() {
      if (selectedDiets.contains(value)) {
        selectedDiets.remove(value);
      } else {
        selectedDiets.add(value);
      }
    });
  }

  void _onNext() {
    if (selectedDiets.isNotEmpty) {
      userData['foodPreferences'] = selectedDiets.join(', ');

      Navigator.pushNamed(
        context,
        '/signup_step_10',
        arguments: userData,
      );
    }
  }

  Widget dietChip(String label, String value) {
    final isSelected = selectedDiets.contains(value);
    return GestureDetector(
      onTap: () => _toggleDiet(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.black,
            ),
          ),
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
            'assets/images/dieta.png',
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: const Color(0xFF0E4568).withOpacity(0.4),
            ),
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
                      const Text(
                        '¿Qué tipo de dieta prefieres?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esto nos ayudará a personalizar tu plan alimenticio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: dietOptions
                            .map((opt) => dietChip(opt['label']!, opt['value']!))
                            .toList(),
                      ),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey(selectedDiets.length),
                          text: 'Siguiente',
                          onPressed: selectedDiets.isNotEmpty ? _onNext : null,
                        ),
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
}
