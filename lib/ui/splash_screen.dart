import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/app_shadows.dart';
import '../core/app_typography.dart';

/// Splash visual de GymGram (Sistema Aurora).
///
/// Widget puramente visual — no contiene lógica de bootstrap.
/// Pensado para usarse mientras se cargan recursos asíncronos
/// (Supabase, Firebase, notificaciones, etc.).
class SplashScreen extends StatelessWidget {
  final bool showProgress;

  const SplashScreen({super.key, this.showProgress = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.deepSkyGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.auroraGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.glow(AppColors.sky400),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 1400.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 28),
              Text(
                'GymGram',
                style: AppTypography.h1.copyWith(color: AppColors.neutral0),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.2, end: 0),
              const Spacer(),
              if (showProgress)
                const Padding(
                  padding: EdgeInsets.only(bottom: 32),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.ember400),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
