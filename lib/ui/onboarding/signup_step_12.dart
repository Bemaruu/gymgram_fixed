import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

class SignupStep12 extends StatefulWidget {
  const SignupStep12({super.key});

  @override
  State<SignupStep12> createState() => _SignupStep12State();
}

class _SignupStep12State extends State<SignupStep12> with TickerProviderStateMixin {
  String? selectedTime;
  late Map<String, dynamic> userData;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, String>> timeOptions = [
    {'label': 'Mañana (antes de las 9:00)', 'value': 'mañana'},
    {'label': 'Media mañana (9:00 - 12:00)', 'value': 'media'},
    {'label': 'Tarde (12:00 - 17:00)', 'value': 'tarde'},
    {'label': 'Noche (después de las 17:00)', 'value': 'noche'},
    {'label': 'Varía según el día', 'value': 'variable'},
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

  void _selectOption(String value) {
    setState(() {
      selectedTime = value;
    });
  }

  void _onNext() {
    if (selectedTime != null) {
      userData['trainingTime'] = selectedTime;

      Navigator.pushNamed(
        context,
        '/signup_step_13',
        arguments: userData,
      );
    }
  }

  Widget optionChip(String label, String value) {
    final isSelected = selectedTime == value;
    return GestureDetector(
      onTap: () => _selectOption(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
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
          // Fondo
          Image.asset(
            'assets/images/hora.png',
            fit: BoxFit.cover,
          ),

          // Blur + capa
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
                        '¡Último paso! ⏰',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '¿Cuál es tu horario habitual de entrenamiento?',
                        textAlign: TextAlign.center,
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
                      const SizedBox(height: 24),

                      GridView.count(
                        crossAxisCount: 1,
                        childAspectRatio: 5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: timeOptions
                            .map((option) => optionChip(option['label']!, option['value']!))
                            .toList(),
                      ),

                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey(selectedTime),
                          text: 'Finalizar',
                          onPressed: selectedTime != null ? _onNext : null,
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
