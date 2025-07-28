import 'package:flutter/material.dart';
import '../shared/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo motivacional
          Image.asset(
            'assets/images/inicio.png',
            fit: BoxFit.cover,
          ),

          // Capa semitransparente para contraste
          Container(
            color: Colors.black.withOpacity(0.3),
          ),

          // Contenido centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
          ClipRRect(
              borderRadius: BorderRadius.circular(20), // Cambia el 20 por el redondeo que te guste
              child: Image.asset(
                'assets/images/logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
               ),
               ),

                const SizedBox(height: 40),

                // Botón: Ya tengo cuenta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: CustomButton(
                    text: '¡ Ya Tengo Cuenta !',
                    onPressed: () {
                      print('Botón presionado');
                      Navigator.pushNamed(context, '/login');
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Botón: Crear cuenta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: CustomButton(
                    text: '¡ Quiero Crear una Cuenta !',
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup_step_1');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
