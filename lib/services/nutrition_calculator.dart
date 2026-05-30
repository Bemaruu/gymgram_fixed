/// Calculadora nutricional de GymGram.
///
/// Usa Mifflin-St Jeor para el metabolismo basal y aplica ajustes
/// basados en objetivo, diferencia de peso, edad y nivel de actividad.
///
/// ESTIMACIÓN GENERAL — no reemplaza asesoría médica o nutricional.
library;

// ── Resultado completo del cálculo ──────────────────────────────────────────

class NutritionResult {
  final int bmr;
  final int maintenanceCalories;
  final int recommendedCalories;
  final int calorieAdjustment;
  final double activityFactorUsed;
  final String goalInterpretation;
  final String strategy;
  final String explanationText;
  final int proteinGrams;
  final int carbsGrams;
  final int fatsGrams;

  const NutritionResult({
    required this.bmr,
    required this.maintenanceCalories,
    required this.recommendedCalories,
    required this.calorieAdjustment,
    required this.activityFactorUsed,
    required this.goalInterpretation,
    required this.strategy,
    required this.explanationText,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });
}

// ── Constantes de nivel de actividad diaria ──────────────────────────────────

class DailyActivityLevel {
  DailyActivityLevel._();
  static const String sedentary = 'sedentary';   // Trabajo de escritorio, poca movilidad
  static const String light     = 'light';        // Mayormente sentado, movimiento ocasional
  static const String moderate  = 'moderate';     // Actividad mixta (por defecto)
  static const String active    = 'active';       // Trabajo físico / camina mucho
  static const String veryActive = 'very_active'; // Trabajo muy físico o deporte diario
}

// ── Calculadora ──────────────────────────────────────────────────────────────

class NutritionCalculator {
  NutritionCalculator._();

  // Límites de seguridad (kcal/día)
  static const double _minCalsFemale = 1200.0;
  static const double _minCalsMale   = 1500.0;
  static const double _maxCals       = 4500.0;

  /// Calcula el plan nutricional completo del usuario.
  ///
  /// [gender]              'MALE' o 'FEMALE'
  /// [age]                 años cumplidos
  /// [weightKg]            peso actual en kg
  /// [heightCm]            estatura en cm
  /// [targetWeightKg]      peso objetivo en kg (usar weightKg si no se tiene)
  /// [fitnessGoal]         'LOSE_WEIGHT' | 'GAIN_MUSCLE' | 'MAINTAIN'
  /// [trainingDaysPerWeek] días de entrenamiento por semana (0–7)
  /// [dailyActivityLevel]  ver constantes DailyActivityLevel
  static NutritionResult calculate({
    required String gender,
    required int age,
    required double weightKg,
    required double heightCm,
    required double targetWeightKg,
    required String fitnessGoal,
    int trainingDaysPerWeek = 3,
    String dailyActivityLevel = DailyActivityLevel.moderate,
    // Preferencia de dieta normalizada: 'vegana'|'vegetariana'|'lowcarb'|
    // 'proteica'|'normal'. Ajusta el reparto de macros (keto/low-carb, etc.).
    String dietPref = 'normal',
    // Si el screening declarado en onboarding marca riesgo, forzamos modo
    // mantenimiento cuando el objetivo seria perder/cutting. Nunca se etiqueta
    // al usuario; solo se evita prescribir deficit.
    bool eatingDisorderRisk = false,
  }) {
    final isFemale = gender.toUpperCase() == 'FEMALE';
    final isSenior = age >= 60;
    final weightDiff = targetWeightKg - weightKg; // negativo = quiere bajar de peso

    // Safety override silencioso para evitar prescribir deficit en perfiles
    // con riesgo declarado en onboarding.
    final normalizedGoal = fitnessGoal.toUpperCase();
    final goalForCalc = (eatingDisorderRisk &&
            (normalizedGoal == 'LOSE_WEIGHT' || normalizedGoal == 'CUTTING'))
        ? 'MAINTAIN'
        : normalizedGoal;

    // 1. Metabolismo basal (Mifflin-St Jeor)
    final bmr = _bmr(
      isFemale: isFemale,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
    );

    // 2. Factor de actividad combinado (actividad diaria + entrenamiento)
    final factor = _activityFactor(
      trainingDaysPerWeek: trainingDaysPerWeek.clamp(0, 7),
      dailyActivityLevel: dailyActivityLevel,
    );

    // 3. Calorías de mantenimiento
    final maintenance = bmr * factor;

    // 4. Interpretación del objetivo + ajuste calórico
    final goal = _interpretGoal(
      fitnessGoal: goalForCalc,
      weightDiff: weightDiff,
      isSenior: isSenior,
      trainingDaysPerWeek: trainingDaysPerWeek,
      weightKg: weightKg,
      heightCm: heightCm,
    );

    // 5. Calorías recomendadas dentro de límites de seguridad
    final rawRecommended = maintenance + goal.adjustment;
    final minCals = isFemale ? _minCalsFemale : _minCalsMale;
    final recommended = rawRecommended.clamp(minCals, _maxCals).round();
    final actualAdjustment = recommended - maintenance.round();

    // 6. Macronutrientes estimados
    final macros = _macros(
      calories: recommended,
      fitnessGoal: goalForCalc,
      goalInterpretation: goal.interpretation,
      weightKg: weightKg,
      dietPref: dietPref,
    );

    // 7. Texto explicativo (lenguaje simple, no técnico)
    final explanation = _explanation(
      maintenanceCalories: maintenance.round(),
      recommendedCalories: recommended,
      isSenior: isSenior,
      weightDiff: weightDiff,
    );

    return NutritionResult(
      bmr: bmr.round(),
      maintenanceCalories: maintenance.round(),
      recommendedCalories: recommended,
      calorieAdjustment: actualAdjustment,
      activityFactorUsed: double.parse(factor.toStringAsFixed(2)),
      goalInterpretation: goal.interpretation,
      strategy: goal.strategy,
      explanationText: explanation,
      proteinGrams: macros.$1,
      carbsGrams: macros.$2,
      fatsGrams: macros.$3,
    );
  }

  // ── Metabolismo basal (Mifflin-St Jeor) ────────────────────────────────────

  static double _bmr({
    required bool isFemale,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    // Hombre: 10p + 6.25h - 5a + 5
    // Mujer:  10p + 6.25h - 5a - 161
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return isFemale ? base - 161 : base + 5;
  }

  // ── Factor de actividad ─────────────────────────────────────────────────────

  /// Combina la actividad diaria/laboral con la frecuencia de entrenamiento.
  /// Evita usar un factor genérico para todos los usuarios.
  static double _activityFactor({
    required int trainingDaysPerWeek,
    required String dailyActivityLevel,
  }) {
    // Base según actividad laboral o diaria
    final double base = switch (dailyActivityLevel) {
      DailyActivityLevel.sedentary  => 1.20,
      DailyActivityLevel.light      => 1.30,
      DailyActivityLevel.moderate   => 1.38,
      DailyActivityLevel.active     => 1.50,
      DailyActivityLevel.veryActive => 1.60,
      _                             => 1.35,
    };

    // Bonus por frecuencia de entrenamiento
    final double bonus = switch (trainingDaysPerWeek) {
      0      => 0.00,
      1      => 0.05,
      2      => 0.08,
      3      => 0.11,
      4      => 0.14,
      5      => 0.17,
      _      => 0.20, // 6-7 días
    };

    return (base + bonus).clamp(1.20, 1.90);
  }

  // ── Interpretación del objetivo ─────────────────────────────────────────────

  static _GoalResult _interpretGoal({
    required String fitnessGoal,
    required double weightDiff,
    required bool isSenior,
    required int trainingDaysPerWeek,
    required double weightKg,
    required double heightCm,
  }) {
    final needsToLose  = weightDiff < -2.0;
    final needsToGain  = weightDiff > 2.0;
    final bmi = _bmi(weightKg: weightKg, heightCm: heightCm);
    final isOverweight = bmi >= 27.0;

    switch (fitnessGoal) {

      // ── Perder grasa ──────────────────────────────────────────────────────
      case 'LOSE_WEIGHT':
        final int adj = isSenior ? -325 : -400;
        return _GoalResult(
          interpretation: isSenior
              ? 'Pérdida de peso gradual (60+)'
              : 'Pérdida de grasa',
          strategy: isSenior
              ? 'Déficit moderado, priorizando salud y energía'
              : 'Déficit moderado sostenible',
          adjustment: adj,
        );

      // ── Ganar masa muscular ───────────────────────────────────────────────
      case 'GAIN_MUSCLE':
        if (isOverweight && needsToLose) {
          // Sobrepeso + quiere bajar → recomposición, no superávit
          return const _GoalResult(
            interpretation: 'Recomposición corporal',
            strategy: 'Déficit suave con alta proteína para preservar músculo',
            adjustment: -175,
          );
        }
        final int surplus = trainingDaysPerWeek >= 5 ? 300 : 200;
        return _GoalResult(
          interpretation: 'Ganancia muscular',
          strategy: 'Superávit moderado para apoyar el crecimiento muscular',
          adjustment: surplus,
        );

      // ── Mantenerse saludable / mantenimiento ──────────────────────────────
      default: // 'MAINTAIN'
        if (needsToLose) {
          // "Mantenerse saludable" pero con peso objetivo menor → pérdida gradual
          final int adj;
          if (weightDiff <= -10) {
            adj = isSenior ? -300 : -375; // Mucho que bajar
          } else if (weightDiff <= -5) {
            adj = isSenior ? -275 : -325; // Moderado
          } else {
            adj = isSenior ? -225 : -275; // Poco (-2 a -5 kg)
          }
          return _GoalResult(
            interpretation: isSenior
                ? 'Pérdida de peso saludable y gradual (60+)'
                : 'Pérdida de peso saludable',
            strategy: 'Déficit suave para avanzar sin perder energía ni músculo',
            adjustment: adj,
          );
        }

        if (needsToGain) {
          return const _GoalResult(
            interpretation: 'Mantenimiento con ganancia suave',
            strategy: 'Pequeño superávit para alcanzar el peso objetivo',
            adjustment: 150,
          );
        }

        // Peso objetivo ≈ peso actual → mantenimiento puro
        return const _GoalResult(
          interpretation: 'Mantenimiento',
          strategy: 'Calorías de mantenimiento para conservar peso y energía',
          adjustment: 0,
        );
    }
  }

  // ── Macronutrientes ─────────────────────────────────────────────────────────

  static (int, int, int) _macros({
    required int calories,
    required String fitnessGoal,
    required String goalInterpretation,
    required double weightKg,
    required String dietPref,
  }) {
    final isGain = fitnessGoal == 'GAIN_MUSCLE' &&
        !goalInterpretation.toLowerCase().contains('recomposición');
    final isLoss = fitnessGoal == 'LOSE_WEIGHT' ||
        goalInterpretation.toLowerCase().contains('pérdida') ||
        goalInterpretation.toLowerCase().contains('recomposición');

    // Reparto base por objetivo: proteína preserva músculo en déficit; carbs
    // empujan rendimiento en ganancia.
    double protPct = isGain ? 0.30 : (isLoss ? 0.35 : 0.28);
    double carbPct = isGain ? 0.45 : (isLoss ? 0.35 : 0.45);
    double fatPct  = isGain ? 0.25 : (isLoss ? 0.30 : 0.27);

    // Ajuste por preferencia de dieta (sobrescribe el reparto de carbos/grasas).
    switch (dietPref) {
      case 'lowcarb': // incluye keto en nuestra normalización
        protPct = 0.32;
        carbPct = 0.13;
        fatPct = 0.55;
        break;
      case 'proteica': // alta en proteína
        protPct = isGain ? 0.35 : 0.40;
        carbPct = isGain ? 0.40 : 0.35;
        fatPct = 0.25;
        break;
      // vegana/vegetariana/normal mantienen el reparto por objetivo.
    }

    // Piso de proteína por peso corporal (g/kg): evita planes bajos en proteína
    // aunque el % calórico sea chico. Más alto si está en déficit o ganancia.
    final double gPerKg = (isLoss || isGain) ? 1.8 : 1.6;
    final int proteinFloor = (weightKg * gPerKg).round();

    int proteinG = (calories * protPct / 4).round();
    if (proteinG < proteinFloor) proteinG = proteinFloor;

    // Reparte las calorías restantes entre carbos y grasas según su ratio,
    // así el total se mantiene ≈ calorías objetivo tras aplicar el piso.
    final double remainingKcal =
        (calories - proteinG * 4).clamp(0, calories).toDouble();
    final double cfSum = carbPct + fatPct;
    final int carbsG = (remainingKcal * (carbPct / cfSum) / 4).round();
    final int fatsG = (remainingKcal * (fatPct / cfSum) / 9).round();

    return (proteinG, carbsG, fatsG);
  }

  // ── Texto explicativo para el usuario ──────────────────────────────────────

  static String _explanation({
    required int maintenanceCalories,
    required int recommendedCalories,
    required bool isSenior,
    required double weightDiff,
  }) {
    final diff = recommendedCalories - maintenanceCalories;

    if (diff < -50) {
      // Déficit activo
      final String suffix = isSenior
          ? ' Priorizamos un déficit moderado para cuidar tu salud y energía.'
          : '';
      return 'Tu mantenimiento estimado es de $maintenanceCalories kcal. '
          'Como tu peso objetivo es menor, recomendamos $recommendedCalories kcal al día '
          'para avanzar de forma gradual y sostenible.$suffix';
    } else if (diff > 50) {
      // Superávit
      return 'Tu mantenimiento estimado es de $maintenanceCalories kcal. '
          'Para favorecer el crecimiento muscular, recomendamos $recommendedCalories kcal al día '
          'con un pequeño superávit.';
    } else {
      // Mantenimiento puro
      return 'Tu mantenimiento estimado es de $maintenanceCalories kcal. '
          'Como tu objetivo es mantener tu peso, recomendamos mantenerte cerca de ese valor.';
    }
  }

  // ── BMI auxiliar ────────────────────────────────────────────────────────────

  static double _bmi({required double weightKg, required double heightCm}) {
    if (heightCm <= 0) return 22.0;
    final h = heightCm / 100;
    return weightKg / (h * h);
  }
}

// ── Clase auxiliar interna ───────────────────────────────────────────────────

class _GoalResult {
  final String interpretation;
  final String strategy;
  final int adjustment; // negativo = déficit, positivo = superávit

  const _GoalResult({
    required this.interpretation,
    required this.strategy,
    required this.adjustment,
  });
}

// ── Casos de validación (ejecutar manualmente para verificar) ────────────────
//
// Caso 1: Mujer, 64 años, 85 kg, 165 cm, objetivo 75 kg, 3x/sem, sedentaria
//   BMR ≈ 1400  |  Factor: 1.31  |  Mant: ~1834  |  Ajuste: -300  |  Rec: ~1534 ✓
//   (si actividad moderate): Factor 1.49 | Mant: ~2086 | Rec: ~1786 ✓
//
// Caso 2: Hombre, 25 años, 80 kg, 180 cm, objetivo 85 kg, GAIN_MUSCLE, 5x/sem
//   BMR ≈ 1805  |  Factor: 1.55  |  Mant: ~2798  |  Ajuste: +300  |  Rec: ~3098 ✓
//
// Caso 3: Mujer, 30 años, 65 kg, 165 cm, objetivo 65 kg, MAINTAIN, light, 3x/sem
//   BMR ≈ 1370  |  Factor: 1.41  |  Mant: ~1932  |  Ajuste: 0    |  Rec: ~1932 ✓
//
// Caso 4: Mujer, 70 años, 90 kg, 160 cm, objetivo 75 kg, sedentaria, 1x/sem
//   BMR ≈ 1389  |  Factor: 1.25  |  Mant: ~1736  |  Ajuste: -300  |  Rec: ~1436 ✓ (> 1200)
//
// Caso 5: Hombre, 28 años, 90 kg, 178 cm, objetivo 82 kg, GAIN_MUSCLE, 4x/sem
//   BMI ≈ 28.4 (sobrepeso) → Recomposición
//   BMR ≈ 1878  |  Factor: 1.52  |  Mant: ~2854  |  Ajuste: -175  |  Rec: ~2679 ✓
