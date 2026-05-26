import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// Scaffold reutilizable que replica el look de las pantallas de signup
/// existentes (imagen de fondo + blur + textos blancos). Se usa SÓLO en
/// pantallas nuevas para mantener la misma línea visual sin duplicar código.
class OnboardingScaffold extends StatelessWidget {
  final String backgroundAsset;
  final String? eyebrow;
  final String title;
  final Widget child;
  final int? step;
  final int? total;

  const OnboardingScaffold({
    super.key,
    required this.backgroundAsset,
    required this.title,
    this.eyebrow,
    required this.child,
    this.step,
    this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(backgroundAsset, fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(color: const Color(0xFF0E4568).withValues(alpha: 0.4)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (step != null && total != null) ...[
                    OnboardingProgress(step: step!, total: total!),
                  ],
                  if (eyebrow != null) ...[
                    Text(
                      eyebrow!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 6,
                          color: Colors.black87,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso del onboarding. Se coloca arriba del contenido en cada
/// pantalla del flujo para que el usuario vea cuánto le falta.
class OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;
  const OnboardingProgress({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final f = (step / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.24),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                widthFactor: f,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: AppColors.auroraGradient,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paso $step de $total',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            shadows: [
              Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Chip con valor interno y label visible. Replica el estilo de los chips
/// usados en signup_step_7/9/10/11.
class OnboardingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool wide;

  const OnboardingChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: wide ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppColors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario "Volver" usado en todas las pantallas de signup.
class OnboardingBackLink extends StatelessWidget {
  const OnboardingBackLink({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          'Volver',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// "Omitir por ahora" — aplica los defaults indicados sobre userData y avanza
/// a `nextRoute`. Se usa en pantallas no críticas (alimentos a evitar,
/// comidas/día, duración de sesión, etc.).
class OnboardingSkipLink extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> defaults;
  final String nextRoute;

  const OnboardingSkipLink({
    super.key,
    required this.userData,
    required this.defaults,
    required this.nextRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextButton(
        onPressed: () {
          defaults.forEach((k, v) {
            userData[k] = v;
          });
          Navigator.pushNamed(context, nextRoute, arguments: userData);
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        child: const Text(
          'Omitir por ahora',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
