import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

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
    final userData = {
      'fullName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'username': _usernameController.text.trim(),
      'password': _passwordController.text.trim(), // Solo si usarás Auth
    };

    Navigator.pushNamed(
      context,
      '/signup_step_2',
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
                        decoration: const InputDecoration(
                          hintText: 'Nombre completo',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Este campo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Correo
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'Correo electrónico',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Usuario
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Nombre de usuario',
                        ),
                        validator: (value) {
                          if (value == null || value.contains(' ')) {
                            return 'Sin espacios, por favor';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
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
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botón Siguiente
                CustomButton(
                  text: 'Siguiente',
                  onPressed: _onNextPressed,
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
            ),
               

          ),
        ),
      ),
    );
  }
}
