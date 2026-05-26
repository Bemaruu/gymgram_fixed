import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../shared/custom_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _btn1Fade;
  late final Animation<Offset> _btn1Slide;
  late final Animation<double> _btn2Fade;
  late final Animation<Offset> _btn2Slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    ));

    _btn1Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _btn1Slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    ));

    _btn2Fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _btn2Slide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/inicio.png',
            fit: BoxFit.cover,
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: const SizedBox.expand(),
          ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: SlideTransition(
                    position: _logoSlide,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                FadeTransition(
                  opacity: _btn1Fade,
                  child: SlideTransition(
                    position: _btn1Slide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: CustomButton(
                        text: '¡ Ya Tengo Cuenta !',
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                FadeTransition(
                  opacity: _btn2Fade,
                  child: SlideTransition(
                    position: _btn2Slide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: CustomButton(
                        text: '¡ Quiero Crear una Cuenta !',
                        color: AppColors.accentOrange,
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup_step_1');
                        },
                      ),
                    ),
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
