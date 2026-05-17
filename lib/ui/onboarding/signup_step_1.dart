import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_shadows.dart';
import '../../core/app_typography.dart';
import '../../core/input_sanitizers.dart';

class SignupStep1 extends StatefulWidget {
  const SignupStep1({super.key});

  @override
  State<SignupStep1> createState() => _SignupStep1State();
}

class _SignupStep1State extends State<SignupStep1> {
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 void _onNextPressed() {
  if (_formKey.currentState!.validate()) {
    // Tipo explícito: a lo largo del flujo se agregan double, List, bool, etc.
    final Map<String, dynamic> userData = {
      'fullName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'username': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
    };

    Navigator.pushNamed(
      context,
      '/signup_consent',
      arguments: userData,
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // [Aurora polish] contenido del onboarding step 1 con
                // animación de entrada y botón "Siguiente" en gradiente.
                // Logo y Título
                const SizedBox(height: 20),
                 ClipRRect(
              borderRadius: BorderRadius.circular(20), // Cambia el 20 por el redondeo que te guste
              child: Image.asset(
                'assets/images/logo.png',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
               ),
               ),
                const SizedBox(height: 16),
                const Text(
                  'Crea tu cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 32),

                // Tarjeta del formulario
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Nombre completo
                      TextFormField(
                        controller: _nameController,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          hintText: 'Nombre completo',
                          counterText: '',
                        ),
                        validator: InputSanitizers.validateFullName,
                      ),
                      const SizedBox(height: 20),

                      // Correo
                      TextFormField(
                        controller: _emailController,
                        maxLength: 254,
                        decoration: const InputDecoration(
                          hintText: 'Correo electrónico',
                          counterText: '',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: InputSanitizers.validateEmail,
                      ),
                      const SizedBox(height: 20),

                      // Usuario
                      TextFormField(
                        controller: _usernameController,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          hintText: 'Nombre de usuario',
                          counterText: '',
                        ),
                        validator: InputSanitizers.validateUsername,
                      ),
                      const SizedBox(height: 20),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          hintText: 'Contraseña (8+ con letras y números)',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          ),
                        ),
                        validator: InputSanitizers.validatePassword,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botón Siguiente (aurora polish)
                Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.auroraGradient,
                    borderRadius: BorderRadius.circular(AppRadius.base),
                    boxShadow: AppShadows.glow(AppColors.ember400),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.base),
                      ),
                    ),
                    onPressed: _onNextPressed,
                    child: Text(
                      'Siguiente',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.neutral0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                 const SizedBox(height: 16),

            GestureDetector(
                onTap: () {
            Navigator.pop(context); // Vuelve a la pantalla anterior
                          },
                  child: const Text(
                  '¿Ya tienes cuenta? Volver',
                   style: TextStyle(
                    fontSize: 14,
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w500,
                 ),
              ),
            ),
              ],
            )
                .animate()
                .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.04, end: 0),
          ),
        ),
      ),
    );
  }
}
