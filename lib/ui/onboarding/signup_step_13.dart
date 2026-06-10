import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/country_utils.dart';
import '../../core/error_messages.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../../models/user_register_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../services/badge_service.dart';
import '../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupStep13 extends StatefulWidget {
  const SignupStep13({super.key});

  @override
  State<SignupStep13> createState() => _SignupStep13State();
}

class _SignupStep13State extends State<SignupStep13>
    with TickerProviderStateMixin {
  // selectedOption ahora es el valor de coaching_style
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

// Mapeos defensivos. El flujo ya guarda en formato UPPERCASE pero estos
// quedan como red de seguridad por si algún paso futuro guarda string libre.
String _mapGender(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized == 'male' || normalized.contains('masc') || normalized == 'hombre') return 'MALE';
  if (normalized == 'female' || normalized.contains('fem') || normalized == 'mujer') return 'FEMALE';
  if (normalized == 'other' || normalized == 'otro') return 'OTHER';
  if (value == value.toUpperCase() && value.isNotEmpty) return value;
  return 'PREFER_NOT_TO_SAY';
}

String _mapFitnessGoal(String value) {
  if (value == value.toUpperCase() && value.isNotEmpty) return value;
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('perd') || normalized.contains('lose')) return 'LOSE_WEIGHT';
  if (normalized.contains('masa') || normalized.contains('gain') || normalized.contains('ganar')) return 'GAIN_MUSCLE';
  if (normalized.contains('recomp')) return 'RECOMPOSITION';
  if (normalized.contains('resist') || normalized.contains('endur')) return 'IMPROVE_ENDURANCE';
  if (normalized.contains('tonif')) return 'TONE_BODY';
  return 'MAINTAIN';
}

String _mapTrainingLocation(String value) {
  if (value == value.toUpperCase() && value.isNotEmpty) return value;
  final normalized = value.toLowerCase().trim();
  if (normalized.contains('gym') || normalized.contains('gimnasio')) return 'GYM';
  if (normalized.contains('outdoor') || normalized.contains('aire')) return 'OUTDOOR';
  if (normalized.contains('hybrid') || normalized.contains('mixto')) return 'HYBRID';
  return 'HOME';
}

  Future<void> _onNext() async {
    if (selectedOption == null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Coaching style + notificaciones derivadas
      userData['coachingStyle'] = selectedOption!;
      userData['notificationsEnabled'] = selectedOption != 'no_notifications';
      userData['bio'] = '';

      // Hidratar modelo tipado desde el Map.
      final model = UserRegisterModel.fromMap(userData);

      final email = model.email ?? '';
      final password = model.password ?? '';
      final username = model.username ?? '';
      final fullName = (model.fullName != null && model.fullName!.isNotEmpty)
          ? model.fullName!
          : username;

      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw Exception('Faltan datos obligatorios del registro.');
      }

      final age = model.birthDate != null && model.birthDate!.isNotEmpty
          ? _calculateAge(model.birthDate!)
          : 18;
      final weight = model.weight ?? 0;
      final height = model.height ?? 0;
      final targetWeight = model.targetWeight ?? weight;
      final gender = _mapGender(model.gender ?? '');
      final goalValue = _mapFitnessGoal(model.fitnessGoal ?? '');
      final trainingLocationValue =
          _mapTrainingLocation(model.trainingLocation ?? '');
      final trainingTime = model.trainingTime ?? 'variable';
      final countryCode = CountryUtils.detectDeviceCountry();

      // 1) Crear usuario en Supabase Auth
      await AuthService().registerWithEmail(email: email, password: password);

      // 2) Crear perfil
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('Error de autenticación. Intenta de nuevo.');
      await SupabaseService.instance.createProfile(
        userId: userId,
        username: username,
        email: email,
        fullName: fullName,
        age: age,
        gender: gender,
        weight: weight,
        height: height,
        targetWeight: targetWeight,
        fitnessGoal: goalValue,
        trainingLocation: trainingLocationValue,
        timeAvailability: trainingTime,
        birthDate: model.birthDate,
        countryCode: countryCode,
      );

      // 3) Medallas de bienvenida
      try {
        await BadgeService.instance.checkAndAwardBadges(userId, 'account_created');
      } catch (e) {
        debugPrint('Badge award warning: $e');
      }

      // 4) Datos extendidos de onboarding
      try {
        final mealsInt = int.tryParse(model.mealsPerDayRaw ?? '');
        final extraMealPref = <String>[];
        if (model.mealsPerDayRaw == 'intermittent_fasting' ||
            model.mealsPerDayRaw == 'flexible') {
          extraMealPref.add(model.mealsPerDayRaw!);
        }

        // Si el usuario importó rutina, sus días reales son las claves de
        // la rutina importada (los que NO están = descanso). Esto evita que
        // step_7 sobreescriba con valores incorrectos.
        final imported = userData['importedRoutine'];
        final List<String> finalAvailableDays;
        if (imported is List && imported.isNotEmpty) {
          finalAvailableDays = imported
              .map((e) => (e as Map)['day_of_week'].toString())
              .toSet()
              .toList()
            ..sort();
        } else {
          finalAvailableDays =
              model.availableDays.map((i) => i.toString()).toList();
        }

        await SupabaseService.instance.saveOnboardingData(
          userId: userId,
          availableDays: finalAvailableDays,
          mealsPerDay: mealsInt,
          foodPreferences: [...model.foodPreferences, ...extraMealPref],
          allergies: model.dietaryRestrictions,
          exercisePreferences: const [],
          timeAvailability: trainingTime,
          experienceLevel: model.trainingLevel ?? '',
          trainingLevel: model.trainingLevel,
          experiencePath: model.experiencePath,
          equipmentAvailable: model.equipmentAvailable,
          sessionDurationMinutes: model.sessionDurationMinutes,
          dailyActivityLevel: model.dailyActivityLevel,
          routineSplitPreference: model.routineSplitPreference,
          injuries: model.injuries,
          injuryNotes: model.injuryNotes,
          cookingTimePreference: model.cookingTimePreference,
          dislikedFoods: model.dislikedFoods,
          coachingStyle: model.coachingStyle,
          notificationsEnabled: model.notificationsEnabled,
          privacyConsentAt: model.privacyConsentAt,
          termsConsentAt: model.termsConsentAt,
          countryCode: countryCode,
        );
      } catch (e) {
        debugPrint('saveOnboardingData warning: $e');
      }

      // 4.5) Guardar campos de health screening en el perfil
      // Si el usuario entró por camino detallado (salud o restricción alimentaria),
      // los flags son OBLIGATORIOS: reintentamos y bloqueamos el avance si falla.
      final healthUpdate = <String, dynamic>{};
      final parq = userData['parqAnswers'];
      if (userData['requiresMedicalClearance'] != null) {
        healthUpdate['requires_medical_clearance'] =
            userData['requiresMedicalClearance'] == true;
      }
      // Riesgo nutricional combinado (recomendación nutricionista 2026-06-08):
      // cualquiera de estas señales activa el modo seguro + mensaje de
      // derivación a profesional: SCOFF ≥ 2, IMC < 18, pérdida de peso
      // involuntaria, o amenorrea / menstruación intermitente (mujeres).
      final bmi = (userData['bmi'] as num?)?.toDouble();
      final lowBmiRisk = bmi != null && bmi < 18.0;
      final involuntaryLoss = userData['weightLossInvoluntary'] == true;
      final menstrualRisk = userData['menstrualRisk'] == true;
      final scoffRisk = userData['eatingDisorderRisk'] == true;
      final nutritionRisk =
          scoffRisk || lowBmiRisk || involuntaryLoss || menstrualRisk;
      healthUpdate['eating_disorder_risk'] = nutritionRisk;
      if (parq is Map) {
        healthUpdate['parq_answers'] = parq;
      }
      if (userData['scoffScore'] is int) {
        healthUpdate['scoff_score'] = userData['scoffScore'];
      }

      final hasHealthIssue = userData['hasHealthIssue'] == true;
      final hasFoodRestriction = userData['hasFoodRestriction'] == true;
      final isMandatory = hasHealthIssue || hasFoodRestriction || nutritionRisk;

      if (healthUpdate.isNotEmpty) {
        if (isMandatory) {
          // UPDATE obligatorio: hasta 2 reintentos con delay de 500ms.
          Object? lastError;
          bool saved = false;
          for (int attempt = 0; attempt < 3; attempt++) {
            try {
              await Supabase.instance.client
                  .from('profiles')
                  .update(healthUpdate)
                  .eq('id', userId);
              saved = true;
              break;
            } catch (e) {
              lastError = e;
              if (attempt < 2) {
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }
          }
          if (!saved) {
            debugPrint('health screening save FAILED (mandatory): $lastError');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No pudimos guardar tus datos de salud. Verifica tu conexión e intenta de nuevo.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return; // NO navegar. _isLoading se resetea en finally.
          }
        } else {
          // Sin datos clínicos críticos: try/catch silencioso.
          try {
            await Supabase.instance.client
                .from('profiles')
                .update(healthUpdate)
                .eq('id', userId);
          } catch (e) {
            debugPrint('health screening save warning: $e');
          }
        }
      }

      // 5) Importar rutina existente si el usuario eligió ese path
      try {
        final imported = userData['importedRoutine'];
        if (imported is List && imported.isNotEmpty) {
          await SupabaseService.instance.importUserRoutine(
            userId: userId,
            days: List<Map<String, dynamic>>.from(
              imported.map((e) => Map<String, dynamic>.from(e as Map)),
            ),
            trainingLocation: trainingLocationValue,
            goal: goalValue,
          );
        }
      } catch (e) {
        debugPrint('importUserRoutine warning: $e');
      }

      AnalyticsService.instance.identify(userId,
          username: username, fitnessGoal: goalValue);
      AnalyticsService.instance.signupCompleted(
        fitnessGoal: goalValue,
        trainingLocation: trainingLocationValue,
        gender: gender,
      );

      // Prefetch IA en background ANTES de navegar. La edge generate-nutrition-plan
      // persiste en `nutrition_plans` (cache DB), asi que la pestaña Alimentacion
      // carga instantaneo cuando el usuario llegue. generate-routine no persiste
      // todavia (TODO: routine_plans table) pero la llamada igual deja Gemini
      // "tibio" y reduce latencia percibida. Fire-and-forget, no bloqueamos
      // la navegacion.
      unawaited(_prefetchAiPlansInBackground());

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main_navigation_screen',
        (route) => false,
        arguments: userData,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(humanizeError(e)),
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

  // Llama a las edges generate-routine y generate-nutrition-plan en paralelo.
  // No bloquea la navegacion; cualquier error se silencia (las pantallas
  // tienen su propio fallback al primer open). El objetivo es que cuando el
  // usuario llegue a las pestañas Rutina / Alimentacion, el plan ya este
  // cacheado en DB (o el servidor ya este calentando la respuesta).
  Future<void> _prefetchAiPlansInBackground() async {
    final client = Supabase.instance.client;
    try {
      await Future.wait<dynamic>([
        client.functions.invoke('generate-routine', body: const {
          'session_duration_min': 60,
        }),
        client.functions.invoke('generate-nutrition-plan', body: const {
          'week_index': 0,
        }),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('Prefetch IA warning (no bloqueante): $e');
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
                      Builder(builder: (_) {
                        final p = OnboardingFlow.progressFor('/signup_step_13', userData);
                        return OnboardingProgress(step: p.step, total: p.total);
                      }),
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
                        '¿Cómo prefieres que te acompañemos?',
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
                      ...OnboardingCatalogs.coachingStyle.map(
                        (o) => optionButton(o.label, o.value),
                      ),
                      const SizedBox(height: 24),
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
