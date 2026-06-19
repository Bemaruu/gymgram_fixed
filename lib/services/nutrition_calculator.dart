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
  // Fibra diaria: NIH DRI = 14 g por cada 1000 kcal.
  final int fiberGrams;
  // Hidratación diaria: ACSM = 35 ml/kg base + 500 ml por sesión de entreno
  // promediada en la semana.
  final int waterMl;
  // Sodio máximo: NIH DRI = 2300 mg/día (1500 si hipertensión declarada).
  final int sodiumMaxMg;

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
    required this.fiberGrams,
    required this.waterMl,
    required this.sodiumMaxMg,
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

  // Límites de seguridad (kcal/día). Pisos validados con nutricionista:
  // 1300 mujeres / 1500 hombres (2026-06-08).
  static const double _minCalsFemale = 1300.0;
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
  /// [goalTimeframeMonths] plazo elegido (3/6/12). null = ritmo por defecto.
  /// [goalExpired]         si el plazo ya venció → fuerza mantenimiento.
  static NutritionResult calculate({
    required String gender,
    required int age,
    required double weightKg,
    required double heightCm,
    required double targetWeightKg,
    required String fitnessGoal,
    int trainingDaysPerWeek = 3,
    String dailyActivityLevel = DailyActivityLevel.moderate,
    // Preferencia de dieta normalizada: 'vegana'|'vegetariana'|'proteica'|
    // 'normal'. 'proteica' empuja la proteína al tope (30%) respetando los
    // pisos de carbos/grasas.
    String dietPref = 'normal',
    // Si el screening declarado en onboarding marca riesgo, forzamos modo
    // mantenimiento cuando el objetivo seria perder/cutting. Nunca se etiqueta
    // al usuario; solo se evita prescribir deficit.
    bool eatingDisorderRisk = false,
    // Si el usuario declaró hipertensión, bajamos el techo de sodio a 1500 mg
    // (AHA / NIH DRI).
    bool hypertension = false,
    // Plazo del objetivo (3/6/12 meses) → modula agresividad del ajuste
    // calórico y proteína DENTRO de las bandas validadas con nutricionista.
    int? goalTimeframeMonths,
    // Si el plazo venció, el plan entra en mantenimiento automáticamente.
    bool goalExpired = false,
  }) {
    final isFemale = gender.toUpperCase() == 'FEMALE';
    final isSenior = age >= 60;
    // Ritmo (pace) según el plazo: define pct/máx de déficit/superávit y g/kg
    // de proteína. null o plazo vencido usan el ritmo por defecto.
    final pace = _paceFor(goalExpired ? null : goalTimeframeMonths);

    // Al vencer el plazo: mantenimiento puro (sostener peso actual), ignorando
    // el peso objetivo para no seguir prescribiendo déficit/superávit.
    final weightDiff =
        goalExpired ? 0.0 : (targetWeightKg - weightKg); // neg = bajar de peso

    // Safety override silencioso para evitar prescribir deficit en perfiles
    // con riesgo declarado en onboarding. El plazo vencido también fuerza
    // mantenimiento.
    final normalizedGoal = fitnessGoal.toUpperCase();
    final goalForCalc = goalExpired
        ? 'MAINTAIN'
        : (eatingDisorderRisk &&
                (normalizedGoal == 'LOSE_WEIGHT' ||
                    normalizedGoal == 'CUTTING'))
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
      maintenance: maintenance,
      pace: pace,
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
      pace: pace,
    );

    // 7. Texto explicativo (lenguaje simple, no técnico)
    final explanation = _explanation(
      maintenanceCalories: maintenance.round(),
      recommendedCalories: recommended,
      isSenior: isSenior,
      weightDiff: weightDiff,
    );

    // 7b. Fibra recomendada: NIH DRI 14 g / 1000 kcal.
    final fiber = (14.0 * recommended / 1000.0).round().clamp(20, 50);

    // 7c. Hidratación: ACSM ~35 ml/kg + reposición por entreno ~500 ml por
    //     sesión repartida en la semana. Mujeres embarazadas o adultos mayores
    //     se mantienen en el mismo rango porque clamp inferior protege.
    final water = (35.0 * weightKg + (500.0 * trainingDaysPerWeek / 7.0))
        .round()
        .clamp(1800, 4500);

    // 7d. Tope sodio: 1500 mg si hipertensión declarada, 2300 mg DRI estándar.
    final sodium = hypertension ? 1500 : 2300;

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
      fiberGrams: fiber,
      waterMl: water,
      sodiumMaxMg: sodium,
    );
  }

  // ── Metabolismo basal (promedio Mifflin-St Jeor + Harris-Benedict) ──────────
  //
  // Recomendación de nutricionista (2026-06-08): promediar dos métodos para
  // ganar precisión en vez de depender de una sola fórmula.

  static double _bmr({
    required bool isFemale,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    // Mifflin-St Jeor (1990)
    // Hombre: 10p + 6.25h - 5a + 5 | Mujer: 10p + 6.25h - 5a - 161
    final mifflin =
        10 * weightKg + 6.25 * heightCm - 5 * age + (isFemale ? -161 : 5);

    // Harris-Benedict revisada (Roza & Shizgal, 1984)
    final harris = isFemale
        ? 447.593 + 9.247 * weightKg + 3.098 * heightCm - 4.330 * age
        : 88.362 + 13.397 * weightKg + 4.799 * heightCm - 5.677 * age;

    return (mifflin + harris) / 2;
  }

  // ── Factor de actividad ─────────────────────────────────────────────────────

  /// Combina la actividad diaria/laboral con la frecuencia de entrenamiento.
  /// Evita usar un factor genérico para todos los usuarios.
  static double _activityFactor({
    required int trainingDaysPerWeek,
    required String dailyActivityLevel,
  }) {
    // Base según actividad laboral o diaria. Escala recalibrada con
    // nutricionista (2026-06-08): piso en sedentario 1.30 para reflejar mejor
    // a la población fitness (que ya entrena), subiendo toda la escala.
    final double base = switch (dailyActivityLevel) {
      DailyActivityLevel.sedentary  => 1.30,
      DailyActivityLevel.light      => 1.40,
      DailyActivityLevel.moderate   => 1.48,
      DailyActivityLevel.active     => 1.58,
      DailyActivityLevel.veryActive => 1.68,
      _                             => 1.48,
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

    return (base + bonus).clamp(1.30, 1.90);
  }

  // ── Interpretación del objetivo ─────────────────────────────────────────────

  static _GoalResult _interpretGoal({
    required String fitnessGoal,
    required double weightDiff,
    required bool isSenior,
    required int trainingDaysPerWeek,
    required double weightKg,
    required double heightCm,
    required double maintenance,
    required _Pace pace,
  }) {
    final needsToLose  = weightDiff < -2.0;
    final needsToGain  = weightDiff > 2.0;
    final bmi = _bmi(weightKg: weightKg, heightCm: heightCm);
    final isOverweight = bmi >= 27.0;

    // Deltas calóricos PROPORCIONALES al mantenimiento, acotados a la banda
    // 300-500 kcal recomendada por nutricionista (2026-06-08). El PLAZO elegido
    // mueve el pct/máx DENTRO de esa banda: 3 meses = más agresivo (cerca del
    // tope), 12 meses = gradual (cerca del piso). Nunca fuera de la banda.
    int deficit({double? pct, int? max}) =>
        (maintenance * (pct ?? pace.deficitPct))
            .round()
            .clamp(300, max ?? pace.deficitMax);
    int surplus({double? pct, int? max}) =>
        (maintenance * (pct ?? pace.surplusPct))
            .round()
            .clamp(300, max ?? pace.surplusMax);
    // Recomposición: déficit muy suave (cerca de mantenimiento) + proteína alta.
    int recompDeficit() => (maintenance * 0.10).round().clamp(250, 400);

    switch (fitnessGoal) {

      // ── Perder grasa ──────────────────────────────────────────────────────
      case 'LOSE_WEIGHT':
        final int adj =
            isSenior ? -deficit(pct: 0.15, max: 400) : -deficit();
        return _GoalResult(
          interpretation: isSenior
              ? 'Pérdida de peso gradual (60+)'
              : 'Pérdida de grasa',
          strategy: isSenior
              ? 'Déficit moderado, priorizando salud y energía'
              : 'Déficit moderado sostenible (~0.5 kg/semana)',
          adjustment: adj,
        );

      // ── Ganar masa muscular ───────────────────────────────────────────────
      case 'GAIN_MUSCLE':
        if (isOverweight && needsToLose) {
          // Sobrepeso + quiere bajar → recomposición, no superávit
          return _GoalResult(
            interpretation: 'Recomposición corporal',
            strategy: 'Déficit suave con alta proteína para preservar músculo',
            adjustment: -recompDeficit(),
          );
        }
        final int adj =
            trainingDaysPerWeek >= 5 ? surplus(pct: 0.15) : surplus();
        return _GoalResult(
          interpretation: 'Ganancia muscular',
          strategy: 'Superávit moderado para apoyar el crecimiento muscular',
          adjustment: adj,
        );

      // ── Recomposición corporal (objetivo explícito) ───────────────────────
      case 'RECOMPOSITION':
        return _GoalResult(
          interpretation: 'Recomposición corporal',
          strategy: 'Cerca de mantenimiento con alta proteína',
          adjustment: -recompDeficit(),
        );

      // ── Mantenerse saludable / mantenimiento ──────────────────────────────
      default: // 'MAINTAIN' (también TONE_BODY / IMPROVE_ENDURANCE)
        if (needsToLose) {
          // "Mantenerse saludable" pero con peso objetivo menor → pérdida gradual
          final int adj = isSenior
              ? -deficit(pct: 0.12, max: 400)
              : -deficit(pct: 0.15, max: 450);
          return _GoalResult(
            interpretation: isSenior
                ? 'Pérdida de peso saludable y gradual (60+)'
                : 'Pérdida de peso saludable',
            strategy: 'Déficit suave para avanzar sin perder energía ni músculo',
            adjustment: adj,
          );
        }

        if (needsToGain) {
          return _GoalResult(
            interpretation: 'Mantenimiento con ganancia suave',
            strategy: 'Pequeño superávit para alcanzar el peso objetivo',
            adjustment: surplus(pct: 0.10, max: 350),
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

  // Distribución validada con nutricionista (2026-06-08):
  //   Proteína 20-30%  |  Carbos 45-55%  |  Grasas 25-35%
  // Pisos DUROS de seguridad: grasas nunca <20%, carbos nunca <40%.
  // Macros ancladas a g/kg de peso corporal (no solo a % calórico).
  static (int, int, int) _macros({
    required int calories,
    required String fitnessGoal,
    required String goalInterpretation,
    required double weightKg,
    required String dietPref,
    required _Pace pace,
  }) {
    final interp = goalInterpretation.toLowerCase();
    final isRecomp = interp.contains('recomp');
    final isGain = fitnessGoal == 'GAIN_MUSCLE' && !isRecomp;
    final isLoss = fitnessGoal == 'LOSE_WEIGHT' ||
        fitnessGoal == 'RECOMPOSITION' ||
        isRecomp ||
        interp.contains('pérdida');
    final highProtein = dietPref == 'proteica' || isRecomp;

    // 1) PROTEÍNA: anclada a g/kg de peso, luego acotada a 20-30% de kcal.
    //    Más alta en déficit/ganancia/recomposición para preservar músculo.
    //    En déficit, el PLAZO sube la proteína (cut más agresivo = más proteína
    //    para preservar masa magra; Helms 2014 / ISSN). Recomp = tope 2.2.
    final double pPerKg = isRecomp
        ? 2.2
        : isLoss
            ? pace.proteinCut
            : isGain
                ? 1.9
                : 1.8;
    double pPct = (weightKg * pPerKg * 4) / calories;
    final double pMax = highProtein ? 0.30 : 0.28;
    pPct = pPct.clamp(0.20, pMax);

    // 2) GRASAS: objetivo por meta dentro de 25-35%, con piso duro de 20%
    //    y mínimo de 0.8 g/kg (salud hormonal).
    double fPct = isGain ? 0.27 : 0.30;
    final double fatFloorPct =
        ((weightKg * 0.8 * 9) / calories).clamp(0.20, 0.35);
    fPct = fPct.clamp(fatFloorPct, 0.35);

    // 3) CARBOS: lo que resta, con piso duro de 40%. Si no alcanza, se libera
    //    bajando primero grasa (hasta su piso) y luego proteína (hasta 20%).
    double cPct = 1.0 - pPct - fPct;
    if (cPct < 0.40) {
      final double needed = 0.40 - cPct;
      final double fatRoom = (fPct - fatFloorPct).clamp(0.0, 1.0);
      final double cutFat = needed < fatRoom ? needed : fatRoom;
      fPct -= cutFat;
      final double rem = needed - cutFat;
      if (rem > 0) {
        final double pRoom = (pPct - 0.20).clamp(0.0, 1.0);
        pPct -= rem < pRoom ? rem : pRoom;
      }
      cPct = 1.0 - pPct - fPct;
    }

    final int proteinG = (calories * pPct / 4).round();
    final int carbsG = (calories * cPct / 4).round();
    final int fatsG = (calories * fPct / 9).round();
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

  // ── Ritmo según el plazo del objetivo ───────────────────────────────────────
  //
  // El plazo (3/6/12 meses) NO sale de las bandas validadas con nutricionista;
  // solo mueve el ajuste DENTRO de ellas: plazo corto = cerca del tope seguro,
  // plazo largo = cerca del piso (gradual). Respaldo de tasas:
  //   - Pérdida de grasa segura: 0.5-1 %/sem del peso (ACSM/NIH). 3m≈tope,
  //     12m≈piso, preservando más músculo cuanto más lento.
  //   - Ganancia magra: superávit +250-500 kcal; cuanto más largo el plazo,
  //     más limpio (menos grasa) — lean bulk (Aragon/Lyle).
  //   - Proteína: 1.6-2.2 g/kg (ISSN/Morton 2018). En déficit se sube para
  //     preservar masa magra; el cut más agresivo (3m) usa el tope 2.2.

  static _Pace _paceFor(int? months) {
    switch (months) {
      case 3: // Exigente pero seguro (cerca del tope de cada banda)
        return const _Pace(
          deficitPct: 0.22, deficitMax: 500,
          surplusPct: 0.15, surplusMax: 450, proteinCut: 2.2);
      case 6: // Moderado y sostenible
        return const _Pace(
          deficitPct: 0.17, deficitMax: 420,
          surplusPct: 0.12, surplusMax: 380, proteinCut: 2.1);
      case 12: // Gradual / lean (mínima pérdida de músculo o ganancia de grasa)
        return const _Pace(
          deficitPct: 0.12, deficitMax: 320,
          surplusPct: 0.09, surplusMax: 320, proteinCut: 2.0);
      default: // Sin plazo: ritmo por defecto (igual al histórico)
        return const _Pace(
          deficitPct: 0.20, deficitMax: 500,
          surplusPct: 0.12, surplusMax: 450, proteinCut: 2.0);
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

// Ritmo del objetivo derivado del plazo (3/6/12 meses). Acotado a las bandas
// validadas con nutricionista: déficit/superávit 300-500/450 kcal, proteína
// 1.8-2.2 g/kg. Ver _paceFor().
class _Pace {
  final double deficitPct; // fracción del mantenimiento para déficit
  final int deficitMax;    // tope kcal del déficit
  final double surplusPct; // fracción del mantenimiento para superávit
  final int surplusMax;    // tope kcal del superávit
  final double proteinCut; // g/kg de proteína en déficit

  const _Pace({
    required this.deficitPct,
    required this.deficitMax,
    required this.surplusPct,
    required this.surplusMax,
    required this.proteinCut,
  });
}

// ── Notas de cálculo (validado con nutricionista 2026-06-08) ─────────────────
//
// BMR: promedio de Mifflin-St Jeor (1990) y Harris-Benedict revisada (1984).
// Factor de actividad: base 1.30 (sedentario) → 1.68 (muy activo) + bonus por
//   días de entreno, clamp [1.30, 1.90].
// Ajuste calórico: proporcional al mantenimiento, acotado a la banda 300-500
//   (déficit ≈20% mant; superávit ≈12%; recomposición ≈10% con proteína alta).
// Macros: P 20-30% / C 45-55% / G 25-35%, ancladas a g/kg, con pisos duros
//   grasas ≥20% y carbos ≥40%. Proteína 2.0 g/kg en déficit/ganancia/recomp.
// Pisos de seguridad kcal: 1300 mujeres / 1500 hombres.
