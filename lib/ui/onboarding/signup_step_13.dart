import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/supabase_service.dart';
import '../shared/custom_button.dart';

class SignupStep13 extends StatefulWidget {
  const SignupStep13({super.key});

  @override
  State<SignupStep13> createState() => _SignupStep13State();
}

class _SignupStep13State extends State<SignupStep13>
    with TickerProviderStateMixin {
  String? selectedOption;
  late Map<String, dynamic> userData;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;

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

  int _calculateAge(String birthDateStr) {
    try {
      final birth = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age.clamp(10, 120);
    } catch (_) {
      return 18;
    }
  }

  String _readString(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = userData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  int _readInt(List<String> keys, {int fallback = 18}) {
    for (final key in keys) {
      final value = userData[key];
      if (value == null) continue;

      if (value is int) return value;

      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  double _readDouble(List<String> keys, {double fallback = 0}) {
    for (final key in keys) {
      final value = userData[key];
      if (value == null) continue;

      if (value is double) return value;
      if (value is int) return value.toDouble();

      final normalized = value.toString().trim().replaceAll(',', '.');
      final parsed = double.tryParse(normalized);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

String _mapGender(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('masc') || normalized == 'male' || normalized == 'hombre') return 'MALE';
  if (normalized.contains('fem') || normalized == 'female' || normalized == 'mujer') return 'FEMALE';
  if (normalized == 'other' || normalized == 'otro') return 'OTHER';
  return 'PREFER_NOT_TO_SAY';
}

String _mapFitnessGoal(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('perd') || normalized.contains('bajar') || normalized.contains('lose')) return 'LOSE_WEIGHT';
  if (normalized.contains('masa') || normalized.contains('musc') || normalized.contains('gain') || normalized.contains('ganar')) return 'GAIN_MUSCLE';
  return 'MAINTAIN';
}

String _mapTrainingLocation(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('gym') || normalized.contains('gimnasio')) return 'GYM';
  return 'HOME';
}

  Future<void> _onNext() async {
    if (selectedOption == null || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      userData['motivationalNotifications'] = selectedOption!;
      userData['bio'] = '';

      final email = _readString(['email', 'correo']);
      final password = _readString(['password', 'contraseña']);
      final username = _readString(['username', 'userName', 'nombreUsuario']);
      final fullName = _readString(['fullName', 'nombreCompleto', 'name'], fallback: username);

      final birthDateStr = _readString(['birthDate', 'fechaNacimiento']);
      final age = birthDateStr.isNotEmpty
          ? _calculateAge(birthDateStr)
          : _readInt(['age', 'edad'], fallback: 18);
      final weight = _readDouble(['weight', 'pesoActual', 'weightKg', 'currentWeight'], fallback: 0);
      final height = _readDouble(['height', 'estatura', 'heightCm'], fallback: 0);
      final targetWeight = _readDouble(['targetWeight', 'pesoObjetivo'], fallback: weight);

      final genderValue = _readString(['gender', 'genero'], fallback: '');
      final goalValue = _readString(['fitnessGoal', 'goal', 'objetivo'], fallback: '');
      final trainingLocationValue =
          _readString(['trainingLocation', 'workoutPlace', 'lugarEntrenamiento', 'trainingPlace'], fallback: '');
      final timeAvailability =
          _readString(['timeAvailability', 'availableTime', 'tiempoEntrenar', 'trainingTime', 'availability'], fallback: 'medium');

      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw Exception('Faltan datos obligatorios del registro.');
      }

      // 1) Crear usuario en Supabase Auth
      await AuthService().registerWithEmail(email: email, password: password);

      // 2) Crear perfil en Supabase
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('Error de autenticación. Intenta de nuevo.');
      await SupabaseService.instance.createProfile(
        userId: userId,
        username: username,
        email: email,
        fullName: fullName,
        age: age,
        gender: _mapGender(genderValue),
        weight: weight,
        height: height,
        targetWeight: targetWeight,
        fitnessGoal: _mapFitnessGoal(goalValue),
        trainingLocation: _mapTrainingLocation(trainingLocationValue),
        timeAvailability: timeAvailability,
        birthDate: birthDateStr.isNotEmpty ? birthDateStr : null,
      );

      // 4) Otorgar medallas de bienvenida: primer_paso + beta_exclusiva
      try {
        final userId = SupabaseService.instance.currentUserId;
        if (userId != null) {
          await BadgeService.instance.checkAndAwardBadges(
            userId,
            'account_created',
          );
        }
      } catch (e) {
        debugPrint('Badge award warning: $e');
      }

      // 5) Guardar datos de onboarding (no crítico, fallo silencioso)
      try {
        final userId = SupabaseService.instance.currentUserId;
        if (userId != null) {
          List<String> splitToList(String raw) => raw.isEmpty
              ? []
              : raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

          final trainingDays = _readString(['trainingDays', 'availableDays']);
          final foodPrefsRaw = _readString(['foodPreferences']);
          final allergiesRaw = _readString(['dietaryRestrictions', 'alergias']);
          final exercisePrefsRaw = _readString(['exercisePreferences']);
          final experienceLevel = _readString(['experienceLevel', 'nivelExperiencia']);
          final mealsPerDayRaw = _readString(['mealsPerDay']);
          final trainingTime = _readString(['trainingTime', 'availability', 'timeAvailability']);

          // Attach 'ayuno'/'flexible' to food prefs since meals_per_day is an int column
          final extraMealPref = (mealsPerDayRaw == 'ayuno' || mealsPerDayRaw == 'flexible')
              ? [mealsPerDayRaw]
              : <String>[];
          final finalFoodPrefs = [...splitToList(foodPrefsRaw), ...extraMealPref];

          await SupabaseService.instance.saveOnboardingData(
            userId: userId,
            availableDays: splitToList(trainingDays),
            mealsPerDay: int.tryParse(mealsPerDayRaw),
            foodPreferences: finalFoodPrefs,
            allergies: splitToList(allergiesRaw),
            exercisePreferences: splitToList(exercisePrefsRaw),
            timeAvailability: trainingTime,
            experienceLevel: experienceLevel,
          );
        }
      } catch (e) {
        debugPrint('saveOnboardingData warning: $e');
      }

      final uid = SupabaseService.instance.currentUserId;
      if (uid != null) {
        AnalyticsService.instance.identify(uid, username: username, fitnessGoal: goalValue);
      }
      AnalyticsService.instance.signupCompleted(
        fitnessGoal: goalValue,
        trainingLocation: trainingLocationValue,
        gender: genderValue,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main_navigation_screen',
        (route) => false,
        arguments: userData,
      );
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'No se pudo crear la cuenta.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget optionButton(String label, String value) {
    final isSelected = selectedOption == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
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
            'assets/images/listo.png',
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: const Color(0xFF0E4568).withValues(alpha: 0.4),
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
                        '¡Último paso! 🔔',
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
                        '¿Quieres recibir notificaciones motivacionales?',
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
                      optionButton('Sí, motivame 💪', 'yes'),
                      optionButton('No, gracias', 'no'),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                key: ValueKey('loading'),
                                color: Colors.white,
                              )
                            : CustomButton(
                                key: ValueKey(selectedOption),
                                text: 'Finalizar',
                                onPressed: selectedOption != null ? _onNext : null,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}