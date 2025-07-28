import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

class SignupStep4 extends StatefulWidget {
  const SignupStep4({super.key});

  @override
  State<SignupStep4> createState() => _SignupStep4State();
}

class _SignupStep4State extends State<SignupStep4> with TickerProviderStateMixin {
  String? selectedPlace;
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

  void _onNext() {
    if (selectedPlace != null) {
      userData['trainingPlace'] = selectedPlace;

      Navigator.pushNamed(
        context,
        '/signup_step_5',
        arguments: userData,
      );
    }
  }

  Widget placeButton(String label, IconData icon, String value, Color color) {
    final isSelected = selectedPlace == value;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPlace = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
            'assets/images/lugar.png',
            fit: BoxFit.cover,
          ),

          // Capa oscura y blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: Colors.black.withAlpha(60),
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
                        '¡Estamos preparando tu rutina!',
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
                        '¿Dónde haces ejercicio?',
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
                      const SizedBox(height: 32),
                      placeButton('Casa', Icons.home, 'Casa', AppColors.primary),
                      placeButton('Gimnasio', Icons.fitness_center, 'Gym', AppColors.accentOrange),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey(selectedPlace),
                          text: 'Siguiente',
                          onPressed: selectedPlace != null ? _onNext : null,
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
