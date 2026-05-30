import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nutrition_calculator.dart';

/// IA simulada para GymGram Beta.
/// Genera rutinas y planes de comida personalizados según el perfil del usuario.
class SimulatedAIService {
  static const String disclaimer =
      'Recomendación generada por IA sobre catálogo validado. No reemplaza consulta profesional.';

  static double calculateBMI(double kg, double cm) {
    if (cm <= 0 || kg <= 0) return 22.0;
    final h = cm / 100;
    return kg / (h * h);
  }

  // ── RUTINAS ────────────────────────────────────────────────────────────────

  /// [trainingDayIndex] = índice 0-based dentro de los días disponibles del usuario.
  /// [totalTrainingDays] = total de días por semana que entrena.
  static List<Map<String, dynamic>> generateRoutine({
    required String goal,
    required String trainingLocation,
    required String gender,
    required double bmi,
    int age = 30,
    int trainingDayIndex = 0,
    int totalTrainingDays = 3,
  }) {
    final isGym = trainingLocation.toUpperCase() == 'GYM';

    // Adultos mayores (60+): rutina suave adaptada
    if (age >= 60) {
      return _seniorSession(isGym: isGym, dayIndex: trainingDayIndex);
    }

    final isGain = goal.toUpperCase() == 'GAIN_MUSCLE';
    final isLose = goal.toUpperCase() == 'LOSE_WEIGHT';
    final isFemale = gender.toUpperCase() == 'FEMALE';
    final highBMI = bmi >= 30.0;

    final focus = _dayFocus(
      index: trainingDayIndex,
      total: totalTrainingDays,
      isGain: isGain,
      isFemale: isFemale,
    );

    if (focus == 'cardio_activo') {
      return _cardioSession(isGym: isGym);
    }

    final int sets = isGain ? 4 : 3;
    final String reps = (highBMI || isLose) ? '15-20' : (isGain ? '6-10' : '10-15');
    final int rest = isGain ? 90 : ((isLose || highBMI) ? 75 : 60);

    final raw = isGym
        ? _gymExercises(focus, isFemale: isFemale)
        : _homeExercises(focus, isFemale: isFemale);

    const warmup = {
      'name': 'Calentamiento dinámico (cardio suave + movilidad articular)',
      'muscle_group': 'Calentamiento',
      'sets': 1,
      'reps': '8-10 min',
      'rest_seconds': 0,
    };

    return [
      warmup,
      ...raw.map((e) => {
        'name': e['name'],
        'muscle_group': e['muscle_group'],
        'sets': e['sets'] ?? sets,
        'reps': e['reps'] ?? reps,
        'rest_seconds': e['rest_seconds'] ?? rest,
      }),
    ];
  }

  // ── Seguridad clinica del fallback ──────────────────────────────────────────

  /// Mapa local de lesiones declaradas al vocabulario de contraindicaciones
  /// del catalogo (lumbar, rodilla, hombro, cervical, muneca, embarazo,
  /// hipertension, cardiaco). Sin tilde en "muneca".
  static const Map<String, String> _injuryToContraindication = {
    'lumbar': 'lumbar',
    'espalda': 'lumbar',
    'espalda baja': 'lumbar',
    'rodilla': 'rodilla',
    'rodillas': 'rodilla',
    'hombro': 'hombro',
    'hombros': 'hombro',
    'cuello': 'cervical',
    'cervical': 'cervical',
    'muneca': 'muneca',
    'muñeca': 'muneca',
    'munecas': 'muneca',
    'muñecas': 'muneca',
  };

  static List<String> _mapInjuriesToContraindications(List<String> injuries) {
    final out = <String>{};
    for (final raw in injuries) {
      final key = raw.toLowerCase().trim();
      final mapped = _injuryToContraindication[key];
      if (mapped != null) out.add(mapped);
    }
    return out.toList();
  }

  /// Lista curada de ejercicios siempre seguros (offline fallback) cuando no
  /// se puede consultar el catalogo y el usuario tiene flags clinicos.
  /// NO depende de equipamiento ni nivel.
  static List<Map<String, dynamic>> _curatedSafeExercises() {
    return const [
      {
        'name': 'Calentamiento dinámico (movilidad articular suave)',
        'muscle_group': 'Calentamiento',
        'sets': 1,
        'reps': '5-8 min',
        'rest_seconds': 0,
      },
      {
        'name': 'Caminata moderada',
        'muscle_group': 'Cardio suave',
        'sets': 1,
        'reps': '15-20 min',
        'rest_seconds': 60,
      },
      {
        'name': 'Bird dog',
        'muscle_group': 'Core / estabilidad',
        'sets': 3,
        'reps': '8 por lado',
        'rest_seconds': 45,
      },
      {
        'name': 'Dead bug',
        'muscle_group': 'Core / estabilidad',
        'sets': 3,
        'reps': '8 por lado',
        'rest_seconds': 45,
      },
      {
        'name': 'Curl con banda elástica',
        'muscle_group': 'Bíceps',
        'sets': 2,
        'reps': '12-15',
        'rest_seconds': 45,
      },
      {
        'name': 'Sentadilla a silla',
        'muscle_group': 'Piernas',
        'sets': 3,
        'reps': '10-12',
        'rest_seconds': 60,
      },
    ];
  }

  /// Versión segura del generador: aplica el filtro de [generateRoutine] y
  /// además excluye ejercicios cuyo `slug` esté contraindicado para las
  /// lesiones / clearance médico del usuario.
  ///
  /// - Si la consulta a Supabase falla (offline o sin sesion), devuelve la
  ///   lista curada [_curatedSafeExercises] cuando haya flags clinicos.
  /// - Si no hay flags clinicos, delega al sync `generateRoutine` sin tocar.
  static Future<List<Map<String, dynamic>>> generateRoutineSafe({
    required String goal,
    required String trainingLocation,
    required String gender,
    required double bmi,
    int age = 30,
    int trainingDayIndex = 0,
    int totalTrainingDays = 3,
    List<String> injuries = const [],
    bool requiresMedicalClearance = false,
  }) async {
    final raw = generateRoutine(
      goal: goal,
      trainingLocation: trainingLocation,
      gender: gender,
      bmi: bmi,
      age: age,
      trainingDayIndex: trainingDayIndex,
      totalTrainingDays: totalTrainingDays,
    );

    final blocked = <String>{
      ..._mapInjuriesToContraindications(injuries),
    };
    if (requiresMedicalClearance) {
      blocked.add('cardiaco');
      blocked.add('hipertension');
    }
    if (blocked.isEmpty) return raw;

    // Intentar filtrar contra exercise_catalog (vocabulario controlado).
    // Si la query falla, caer a lista curada.
    try {
      final names = raw
          .map((e) => (e['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isEmpty) {
        return requiresMedicalClearance ? _curatedSafeExercises() : raw;
      }
      final rows = await Supabase.instance.client
          .from('exercise_catalog')
          .select('name_es, contraindications')
          .inFilter('name_es', names);

      final unsafe = <String>{};
      for (final r in (rows as List)) {
        final map = r as Map<String, dynamic>;
        final cs = (map['contraindications'] as List?)?.cast<String>() ?? const [];
        if (cs.isEmpty) continue;
        for (final c in cs) {
          if (blocked.contains(c)) {
            unsafe.add((map['name_es'] as String?) ?? '');
            break;
          }
        }
      }

      final filtered = raw.where((e) {
        final name = (e['name'] as String?)?.trim() ?? '';
        return !unsafe.contains(name);
      }).toList();

      // Si despues del filtro queda casi vacio y hay clearance, mejor curado.
      if (requiresMedicalClearance && filtered.length < 2) {
        return _curatedSafeExercises();
      }
      return filtered;
    } catch (e) {
      debugPrint('generateRoutineSafe catalog filter failed: $e');
      // Sin red: en perfiles con flags clinicos preferimos curado a prescribir
      // ciegamente.
      return _curatedSafeExercises();
    }
  }

  static String _dayFocus({
    required int index,
    required int total,
    required bool isGain,
    required bool isFemale,
  }) {
    switch (total) {
      case 1: return 'full_a';
      case 2: return ['full_a', 'full_b'][index % 2];
      case 3:
        if (isGain) return ['push', 'pull', 'legs'][index % 3];
        return ['full_a', 'full_posterior', 'cardio_activo'][index % 3];
      case 4:
        return isFemale
            ? ['upper_push', 'lower_glutes', 'upper_pull', 'lower_posterior'][index % 4]
            : ['upper_push', 'lower_quads', 'upper_pull', 'lower_posterior'][index % 4];
      case 5:
        if (isGain) return ['push', 'pull', 'legs', 'shoulders_arms', 'lower_posterior'][index % 5];
        return ['upper_push', 'lower_quads', 'cardio_activo', 'upper_pull', 'lower_posterior'][index % 5];
      case 6:
        return ['push', 'pull', 'legs', 'push_b', 'pull_b', 'lower_glutes'][index % 6];
      default: // 7+ días → forzar patrón de 6 con descanso implícito
        return ['push', 'pull', 'legs', 'push_b', 'pull_b', 'lower_glutes'][index % 6];
    }
  }

  // ── GYM ───────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _gymExercises(String focus, {required bool isFemale}) {
    switch (focus) {
      case 'push':
      case 'upper_push':
        return isFemale ? _gymPushF : _gymPushM;
      case 'push_b':
        return isFemale ? _gymPushBF : _gymPushBM;
      case 'pull':
      case 'upper_pull':
        return isFemale ? _gymPullF : _gymPullM;
      case 'pull_b':
        return isFemale ? _gymPullBF : _gymPullBM;
      case 'legs':
      case 'lower_quads':
        return isFemale ? _gymLegsF : _gymLegsM;
      case 'lower_glutes':
        return _gymGlutes;
      case 'lower_posterior':
        return isFemale ? _gymPosteriorF : _gymPosteriorM;
      case 'shoulders_core':
        return _gymShoulderCore;
      case 'shoulders_arms':
        return isFemale ? _gymShouldersArmsF : _gymShouldersArmsM;
      case 'full_posterior':
      case 'full_b':
        return isFemale ? _gymFullPosteriorF : _gymFullPosteriorM;
      default: // full_a
        return isFemale ? _gymFullAF : _gymFullAM;
    }
  }

  static const _gymPushM = [
    {'name': 'Press de banca con barra', 'muscle_group': 'Pecho'},
    {'name': 'Press inclinado con mancuernas', 'muscle_group': 'Pecho alto'},
    {'name': 'Aperturas en polea baja', 'muscle_group': 'Pecho'},
    {'name': 'Press militar con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Extensión de tríceps en polea alta', 'muscle_group': 'Tríceps'},
    {'name': 'Fondos en paralelas', 'muscle_group': 'Tríceps'},
  ];
  static const _gymPushBM = [
    {'name': 'Press declinado con barra', 'muscle_group': 'Pecho bajo'},
    {'name': 'Press de hombros con barra', 'muscle_group': 'Hombros'},
    {'name': 'Crossover en polea alta', 'muscle_group': 'Pecho'},
    {'name': 'Elevaciones laterales con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Press francés con EZ', 'muscle_group': 'Tríceps'},
    {'name': 'Kickbacks de tríceps', 'muscle_group': 'Tríceps'},
  ];
  static const _gymPullM = [
    {'name': 'Jalón al pecho agarre ancho', 'muscle_group': 'Espalda'},
    {'name': 'Remo con barra', 'muscle_group': 'Espalda'},
    {'name': 'Remo con mancuerna unilateral', 'muscle_group': 'Espalda'},
    {'name': 'Remo en máquina Hammer', 'muscle_group': 'Espalda'},
    {'name': 'Curl con barra recta', 'muscle_group': 'Bíceps'},
    {'name': 'Curl martillo con mancuernas', 'muscle_group': 'Bíceps'},
  ];
  static const _gymPullBM = [
    {'name': 'Dominadas con lastre', 'muscle_group': 'Espalda'},
    {'name': 'Remo en T-bar', 'muscle_group': 'Espalda'},
    {'name': 'Remo Pendlay', 'muscle_group': 'Espalda'},
    {'name': 'Face pulls en polea', 'muscle_group': 'Hombros post.'},
    {'name': 'Curl concentrado', 'muscle_group': 'Bíceps'},
    {'name': 'Curl en polea baja', 'muscle_group': 'Bíceps'},
  ];
  static const _gymLegsM = [
    {'name': 'Sentadilla libre con barra', 'muscle_group': 'Cuádriceps'},
    {'name': 'Prensa de piernas 45°', 'muscle_group': 'Cuádriceps'},
    {'name': 'Hack squat', 'muscle_group': 'Cuádriceps'},
    {'name': 'Extensiones de cuádriceps', 'muscle_group': 'Cuádriceps'},
    {'name': 'Zancadas con mancuernas', 'muscle_group': 'Piernas'},
    {'name': 'Elevación de pantorrillas de pie', 'muscle_group': 'Pantorrillas'},
  ];
  static const _gymPosteriorM = [
    {'name': 'Peso muerto convencional', 'muscle_group': 'Cadena posterior'},
    {'name': 'Peso muerto rumano', 'muscle_group': 'Femoral'},
    {'name': 'Curl femoral acostado', 'muscle_group': 'Femoral'},
    {'name': 'Hip thrust con barra', 'muscle_group': 'Glúteos'},
    {'name': 'Good mornings', 'muscle_group': 'Lumbar'},
    {'name': 'Elevación de pantorrillas sentado', 'muscle_group': 'Pantorrillas'},
  ];
  static const _gymFullAM = [
    {'name': 'Sentadilla con barra', 'muscle_group': 'Piernas'},
    {'name': 'Press de banca', 'muscle_group': 'Pecho'},
    {'name': 'Remo con mancuerna', 'muscle_group': 'Espalda'},
    {'name': 'Press militar', 'muscle_group': 'Hombros'},
    {'name': 'Curl con barra', 'muscle_group': 'Bíceps'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
  ];

  // Female gym
  static const _gymPushF = [
    {'name': 'Press de pecho en máquina', 'muscle_group': 'Pecho'},
    {'name': 'Press inclinado con mancuernas', 'muscle_group': 'Pecho alto'},
    {'name': 'Aperturas en máquina', 'muscle_group': 'Pecho'},
    {'name': 'Press de hombros con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones laterales', 'muscle_group': 'Hombros'},
    {'name': 'Extensión tríceps cuerda', 'muscle_group': 'Tríceps'},
  ];
  static const _gymPushBF = [
    {'name': 'Press de pecho en cables cruzados', 'muscle_group': 'Pecho'},
    {'name': 'Press Arnold con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Fondos asistidos en máquina', 'muscle_group': 'Tríceps'},
    {'name': 'Elevaciones frontales mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Kickbacks de tríceps con mancuerna', 'muscle_group': 'Tríceps'},
    {'name': 'Extensión tríceps sobre cabeza', 'muscle_group': 'Tríceps'},
  ];
  static const _gymPullF = [
    {'name': 'Jalón al pecho agarre neutro', 'muscle_group': 'Espalda'},
    {'name': 'Remo en máquina', 'muscle_group': 'Espalda'},
    {'name': 'Face pulls en polea', 'muscle_group': 'Hombros post.'},
    {'name': 'Remo con mancuerna unilateral', 'muscle_group': 'Espalda'},
    {'name': 'Curl de bíceps con mancuernas', 'muscle_group': 'Bíceps'},
    {'name': 'Curl en polea baja', 'muscle_group': 'Bíceps'},
  ];
  static const _gymPullBF = [
    {'name': 'Remo en polea baja agarre ancho', 'muscle_group': 'Espalda'},
    {'name': 'Jalón agarre estrecho neutro', 'muscle_group': 'Espalda'},
    {'name': 'Row inclinado con mancuernas', 'muscle_group': 'Espalda'},
    {'name': 'Curl Zottman', 'muscle_group': 'Bíceps'},
    {'name': 'Curl concentrado', 'muscle_group': 'Bíceps'},
    {'name': 'Posterior de hombros en polea', 'muscle_group': 'Hombros post.'},
  ];
  static const _gymGlutes = [
    {'name': 'Hip thrust con barra', 'muscle_group': 'Glúteos', 'sets': 4},
    {'name': 'Sentadilla sumo con mancuerna', 'muscle_group': 'Glúteos'},
    {'name': 'Kickbacks de glúteo en polea', 'muscle_group': 'Glúteos'},
    {'name': 'Abductor en máquina', 'muscle_group': 'Glúteos'},
    {'name': 'Sentadilla búlgara', 'muscle_group': 'Cuádriceps/Glúteos'},
    {'name': 'Step-ups con mancuernas', 'muscle_group': 'Piernas'},
  ];
  static const _gymLegsF = [
    {'name': 'Sentadilla en máquina Smith', 'muscle_group': 'Cuádriceps'},
    {'name': 'Prensa de piernas 45°', 'muscle_group': 'Cuádriceps'},
    {'name': 'Extensiones de cuádriceps', 'muscle_group': 'Cuádriceps'},
    {'name': 'Zancadas caminando con mancuernas', 'muscle_group': 'Piernas'},
    {'name': 'Goblet squat con mancuerna', 'muscle_group': 'Cuádriceps'},
    {'name': 'Elevación de pantorrillas de pie', 'muscle_group': 'Pantorrillas'},
  ];
  static const _gymPosteriorF = [
    {'name': 'Peso muerto rumano con mancuernas', 'muscle_group': 'Femoral'},
    {'name': 'Curl femoral acostado', 'muscle_group': 'Femoral'},
    {'name': 'Puente de glúteos con barra', 'muscle_group': 'Glúteos'},
    {'name': 'Good mornings', 'muscle_group': 'Lumbar'},
    {'name': 'Sentadilla búlgara posterior', 'muscle_group': 'Femoral/Glúteo'},
    {'name': 'Abductor en máquina sentada', 'muscle_group': 'Glúteos'},
  ];
  static const _gymShoulderCore = [
    {'name': 'Press militar con barra', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones laterales con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Face pulls en polea', 'muscle_group': 'Hombros post.'},
    {'name': 'Pájaros con mancuernas', 'muscle_group': 'Hombros post.'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
    {'name': 'Elevación de piernas colgado', 'muscle_group': 'Core'},
    {'name': 'Crunch en polea', 'muscle_group': 'Core'},
  ];
  static const _gymFullAF = [
    {'name': 'Hip thrust con barra', 'muscle_group': 'Glúteos', 'sets': 4},
    {'name': 'Sentadilla búlgara', 'muscle_group': 'Cuádriceps/Glúteos'},
    {'name': 'Press de pecho en máquina', 'muscle_group': 'Pecho'},
    {'name': 'Jalón al pecho neutro', 'muscle_group': 'Espalda'},
    {'name': 'Elevaciones laterales', 'muscle_group': 'Hombros'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
  ];
  static const _gymFullPosteriorM = [
    {'name': 'Jalón al pecho agarre ancho', 'muscle_group': 'Espalda'},
    {'name': 'Remo con mancuerna unilateral', 'muscle_group': 'Espalda'},
    {'name': 'Curl con barra recta', 'muscle_group': 'Bíceps'},
    {'name': 'Curl martillo con mancuernas', 'muscle_group': 'Bíceps'},
    {'name': 'Hip thrust con barra', 'muscle_group': 'Glúteos', 'sets': 4},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
  ];
  static const _gymFullPosteriorF = [
    {'name': 'Jalón al pecho agarre neutro', 'muscle_group': 'Espalda'},
    {'name': 'Remo con mancuerna unilateral', 'muscle_group': 'Espalda'},
    {'name': 'Curl de bíceps con mancuernas', 'muscle_group': 'Bíceps'},
    {'name': 'Hip thrust con barra', 'muscle_group': 'Glúteos', 'sets': 4},
    {'name': 'Peso muerto rumano con mancuernas', 'muscle_group': 'Femoral'},
    {'name': 'Plancha lateral', 'muscle_group': 'Core', 'reps': '30s'},
  ];
  static const _gymShouldersArmsM = [
    {'name': 'Press militar con barra', 'muscle_group': 'Hombros', 'sets': 4},
    {'name': 'Elevaciones laterales con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Face pulls en polea', 'muscle_group': 'Hombros post.'},
    {'name': 'Curl con barra recta', 'muscle_group': 'Bíceps', 'sets': 4},
    {'name': 'Curl martillo con mancuernas', 'muscle_group': 'Bíceps'},
    {'name': 'Press francés con EZ', 'muscle_group': 'Tríceps', 'sets': 4},
    {'name': 'Extensión tríceps en polea alta', 'muscle_group': 'Tríceps'},
  ];
  static const _gymShouldersArmsF = [
    {'name': 'Press Arnold con mancuernas', 'muscle_group': 'Hombros', 'sets': 3},
    {'name': 'Elevaciones laterales con mancuernas', 'muscle_group': 'Hombros'},
    {'name': 'Face pulls en polea', 'muscle_group': 'Hombros post.'},
    {'name': 'Curl de bíceps con mancuernas', 'muscle_group': 'Bíceps', 'sets': 3},
    {'name': 'Curl concentrado', 'muscle_group': 'Bíceps'},
    {'name': 'Extensión tríceps cuerda', 'muscle_group': 'Tríceps', 'sets': 3},
    {'name': 'Kickbacks de tríceps con mancuerna', 'muscle_group': 'Tríceps'},
  ];

  // ── HOME ──────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _homeExercises(String focus, {required bool isFemale}) {
    switch (focus) {
      case 'push':
      case 'upper_push':
        return isFemale ? _homePushF : _homePushM;
      case 'push_b':
        return isFemale ? _homePushBF : _homePushBM;
      case 'pull':
      case 'upper_pull':
        return isFemale ? _homePullF : _homePullM;
      case 'pull_b':
        return isFemale ? _homePullBF : _homePullBM;
      case 'legs':
      case 'lower_quads':
        return isFemale ? _homeLegsF : _homeLegsM;
      case 'lower_glutes':
        return isFemale ? _homeGlutesF : _homeGlutesM;
      case 'lower_posterior':
        return isFemale ? _homePosteriorF : _homePosteriorM;
      case 'shoulders_core':
        return _homeShoulderCore;
      case 'shoulders_arms':
        return isFemale ? _homeShouldersArmsF : _homeShouldersArmsM;
      case 'full_posterior':
      case 'full_b':
        return isFemale ? _homeFullPosteriorF : _homeFullPosteriorM;
      default:
        return isFemale ? _homeFullAF : _homeFullAM;
    }
  }

  static const _homePushM = [
    {'name': 'Flexiones', 'muscle_group': 'Pecho'},
    {'name': 'Flexiones con pies elevados', 'muscle_group': 'Pecho alto'},
    {'name': 'Flexiones diamante', 'muscle_group': 'Tríceps'},
    {'name': 'Flexiones pike', 'muscle_group': 'Hombros'},
    {'name': 'Dips entre sillas', 'muscle_group': 'Tríceps'},
    {'name': 'Flexiones con pausa', 'muscle_group': 'Pecho'},
  ];
  static const _homePushBM = [
    {'name': 'Flexiones explosivas (clap)', 'muscle_group': 'Pecho'},
    {'name': 'Flexiones archer', 'muscle_group': 'Pecho'},
    {'name': 'Fondos en silla', 'muscle_group': 'Tríceps'},
    {'name': 'Extensión tríceps con mochila', 'muscle_group': 'Tríceps'},
    {'name': 'Flexiones declinadas', 'muscle_group': 'Pecho bajo'},
    {'name': 'Flexiones Spiderman', 'muscle_group': 'Pecho/Core'},
  ];
  static const _homePullM = [
    {'name': 'Dominadas en barra', 'muscle_group': 'Espalda'},
    {'name': 'Remo bajo con mochila', 'muscle_group': 'Espalda'},
    {'name': 'Superman con brazos extendidos', 'muscle_group': 'Lumbar'},
    {'name': 'Remo invertido en mesa', 'muscle_group': 'Espalda'},
    {'name': 'Curl de bíceps con mochila', 'muscle_group': 'Bíceps'},
    {'name': 'Chin-ups', 'muscle_group': 'Bíceps/Espalda'},
  ];
  static const _homePullBM = [
    {'name': 'Pull-ups agarre neutro', 'muscle_group': 'Espalda'},
    {'name': 'Remo unilateral con mochila', 'muscle_group': 'Espalda'},
    {'name': 'Superman compuesto', 'muscle_group': 'Lumbar'},
    {'name': 'Curl concentrado con botella', 'muscle_group': 'Bíceps'},
    {'name': 'Australian pull-ups', 'muscle_group': 'Espalda'},
    {'name': 'Face pulls con elástico', 'muscle_group': 'Hombros post.'},
  ];
  static const _homeLegsM = [
    {'name': 'Sentadilla', 'muscle_group': 'Cuádriceps'},
    {'name': 'Sentadilla búlgara', 'muscle_group': 'Cuádriceps'},
    {'name': 'Zancadas caminando', 'muscle_group': 'Piernas'},
    {'name': 'Sentadilla jump', 'muscle_group': 'Explosivo'},
    {'name': 'Step-ups en silla', 'muscle_group': 'Piernas'},
    {'name': 'Pantorrillas de pie', 'muscle_group': 'Pantorrillas'},
  ];
  static const _homeGlutesM = [
    {'name': 'Hip thrust con peso corporal', 'muscle_group': 'Glúteos'},
    {'name': 'Sentadilla sumo', 'muscle_group': 'Glúteos'},
    {'name': 'Puente de glúteos unipodal', 'muscle_group': 'Glúteos'},
    {'name': 'Kickback en cuadrupedia', 'muscle_group': 'Glúteos'},
    {'name': 'Zancadas laterales', 'muscle_group': 'Glúteos'},
    {'name': 'Sentadilla pistol asistida', 'muscle_group': 'Piernas'},
  ];
  static const _homePosteriorM = [
    {'name': 'Peso muerto unipodal sin peso', 'muscle_group': 'Femoral'},
    {'name': 'Puente de glúteos', 'muscle_group': 'Glúteos'},
    {'name': 'Nordic curl modificado', 'muscle_group': 'Femoral'},
    {'name': 'Buenos días con peso corporal', 'muscle_group': 'Lumbar'},
    {'name': 'Hip thrust unilateral', 'muscle_group': 'Glúteos'},
    {'name': 'Curl femoral en suelo', 'muscle_group': 'Femoral'},
  ];
  static const _homeShoulderCore = [
    {'name': 'Flexiones pike', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones frontales con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
    {'name': 'Crunch bicicleta', 'muscle_group': 'Core'},
    {'name': 'Plancha lateral', 'muscle_group': 'Oblicuos', 'reps': '30s'},
    {'name': 'Mountain climbers', 'muscle_group': 'Core'},
    {'name': 'Dead bug', 'muscle_group': 'Core'},
  ];
  static const _homeFullAM = [
    {'name': 'Sentadilla', 'muscle_group': 'Piernas'},
    {'name': 'Flexiones', 'muscle_group': 'Pecho'},
    {'name': 'Dominadas', 'muscle_group': 'Espalda'},
    {'name': 'Hip thrust', 'muscle_group': 'Glúteos'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
    {'name': 'Burpees', 'muscle_group': 'Full body'},
  ];

  // Home female
  static const _homePushF = [
    {'name': 'Flexiones modificadas (rodillas)', 'muscle_group': 'Pecho'},
    {'name': 'Flexiones pike', 'muscle_group': 'Hombros'},
    {'name': 'Dips en silla', 'muscle_group': 'Tríceps'},
    {'name': 'Flexiones con pausa', 'muscle_group': 'Pecho'},
    {'name': 'Plancha a extensión de brazo', 'muscle_group': 'Hombros/Core'},
    {'name': 'Flexiones inclinadas (manos altas)', 'muscle_group': 'Pecho'},
  ];
  static const _homePushBF = [
    {'name': 'Flexiones sumo', 'muscle_group': 'Pecho interno'},
    {'name': 'Press overhead con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Extensión tríceps con botella', 'muscle_group': 'Tríceps'},
    {'name': 'Flexiones diamante modificadas', 'muscle_group': 'Tríceps'},
    {'name': 'Elevaciones laterales con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Fondos entre sillas', 'muscle_group': 'Tríceps'},
  ];
  static const _homePullF = [
    {'name': 'Dominadas asistidas o negativas', 'muscle_group': 'Espalda'},
    {'name': 'Remo bajo con mochila', 'muscle_group': 'Espalda'},
    {'name': 'Superman', 'muscle_group': 'Lumbar'},
    {'name': 'Australian pull-ups en mesa', 'muscle_group': 'Espalda'},
    {'name': 'Curl de bíceps con botellas', 'muscle_group': 'Bíceps'},
    {'name': 'Row bird-dog', 'muscle_group': 'Espalda/Core'},
  ];
  static const _homePullBF = [
    {'name': 'Remo unilateral con mochila', 'muscle_group': 'Espalda'},
    {'name': 'Superman isométrico', 'muscle_group': 'Lumbar'},
    {'name': 'Reverse snow angels', 'muscle_group': 'Hombros post.'},
    {'name': 'Curl concentrado con botella', 'muscle_group': 'Bíceps'},
    {'name': 'Face pulls con elástico', 'muscle_group': 'Hombros post.'},
    {'name': 'Hyperextensions en suelo', 'muscle_group': 'Lumbar'},
  ];
  static const _homeGlutesF = [
    {'name': 'Hip thrust con peso corporal', 'muscle_group': 'Glúteos'},
    {'name': 'Sentadilla sumo con pausa', 'muscle_group': 'Glúteos'},
    {'name': 'Kickback en cuadrupedia', 'muscle_group': 'Glúteos'},
    {'name': 'Fire hydrant', 'muscle_group': 'Glúteos'},
    {'name': 'Puente glúteo unipodal', 'muscle_group': 'Glúteos'},
    {'name': 'Clamshell', 'muscle_group': 'Glúteos'},
  ];
  static const _homeLegsF = [
    {'name': 'Sentadilla búlgara', 'muscle_group': 'Cuádriceps/Glúteos'},
    {'name': 'Zancadas caminando', 'muscle_group': 'Piernas'},
    {'name': 'Step-ups en silla', 'muscle_group': 'Piernas'},
    {'name': 'Sentadilla estrecha con pausa', 'muscle_group': 'Cuádriceps'},
    {'name': 'Sentadilla sumo', 'muscle_group': 'Glúteos'},
    {'name': 'Saltos en sentadilla', 'muscle_group': 'Explosivo'},
  ];
  static const _homePosteriorF = [
    {'name': 'Peso muerto unipodal sin peso', 'muscle_group': 'Femoral'},
    {'name': 'Nordic curl modificado', 'muscle_group': 'Femoral'},
    {'name': 'Puente glúteo isométrico', 'muscle_group': 'Glúteos'},
    {'name': 'Frog pumps', 'muscle_group': 'Glúteos'},
    {'name': 'Hip thrust pulsaciones', 'muscle_group': 'Glúteos'},
    {'name': 'Buenos días con peso corporal', 'muscle_group': 'Lumbar'},
  ];
  static const _homeFullAF = [
    {'name': 'Hip thrust', 'muscle_group': 'Glúteos'},
    {'name': 'Sentadilla búlgara', 'muscle_group': 'Cuádriceps'},
    {'name': 'Flexiones modificadas', 'muscle_group': 'Pecho'},
    {'name': 'Dominadas asistidas', 'muscle_group': 'Espalda'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
    {'name': 'Fire hydrant', 'muscle_group': 'Glúteos'},
  ];
  static const _homeFullPosteriorM = [
    {'name': 'Australian pull-ups', 'muscle_group': 'Espalda'},
    {'name': 'Remo bajo con mochila', 'muscle_group': 'Espalda'},
    {'name': 'Curl de bíceps con mochila', 'muscle_group': 'Bíceps'},
    {'name': 'Hip thrust con peso corporal', 'muscle_group': 'Glúteos'},
    {'name': 'Superman con brazos extendidos', 'muscle_group': 'Lumbar'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
  ];
  static const _homeFullPosteriorF = [
    {'name': 'Australian pull-ups en mesa', 'muscle_group': 'Espalda'},
    {'name': 'Superman', 'muscle_group': 'Lumbar'},
    {'name': 'Curl de bíceps con botellas', 'muscle_group': 'Bíceps'},
    {'name': 'Hip thrust con peso corporal', 'muscle_group': 'Glúteos'},
    {'name': 'Puente glúteo unipodal', 'muscle_group': 'Glúteos'},
    {'name': 'Plancha', 'muscle_group': 'Core', 'reps': '45s'},
  ];
  static const _homeShouldersArmsM = [
    {'name': 'Flexiones pike', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones frontales con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones laterales con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Curl de bíceps con mochila', 'muscle_group': 'Bíceps'},
    {'name': 'Curl concentrado con botella', 'muscle_group': 'Bíceps'},
    {'name': 'Flexiones diamante', 'muscle_group': 'Tríceps'},
    {'name': 'Dips entre sillas', 'muscle_group': 'Tríceps'},
  ];
  static const _homeShouldersArmsF = [
    {'name': 'Flexiones pike', 'muscle_group': 'Hombros'},
    {'name': 'Press overhead con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Elevaciones laterales con botellas', 'muscle_group': 'Hombros'},
    {'name': 'Curl de bíceps con botellas', 'muscle_group': 'Bíceps'},
    {'name': 'Curl concentrado con botella', 'muscle_group': 'Bíceps'},
    {'name': 'Extensión tríceps con botella', 'muscle_group': 'Tríceps'},
    {'name': 'Fondos entre sillas', 'muscle_group': 'Tríceps'},
  ];

  static List<Map<String, dynamic>> _cardioSession({required bool isGym}) {
    if (isGym) {
      return [
        {'name': 'Cinta a ritmo moderado 20 min', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '20 min', 'rest_seconds': 0},
        {'name': 'Bicicleta estática', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '15 min', 'rest_seconds': 0},
        {'name': 'Estiramientos dinámicos', 'muscle_group': 'Movilidad', 'sets': 1, 'reps': '10 min', 'rest_seconds': 0},
      ];
    }
    return [
      {'name': 'Saltar la cuerda o jumping jacks', 'muscle_group': 'Cardio', 'sets': 3, 'reps': '1 min', 'rest_seconds': 30},
      {'name': 'Trote en el lugar', 'muscle_group': 'Cardio', 'sets': 3, 'reps': '2 min', 'rest_seconds': 30},
      {'name': 'Estiramientos y movilidad', 'muscle_group': 'Movilidad', 'sets': 1, 'reps': '10 min', 'rest_seconds': 0},
    ];
  }

  // ── RUTINA ADULTOS MAYORES (60+) ──────────────────────────────────────────

  static List<Map<String, dynamic>> _seniorSession({required bool isGym, required int dayIndex}) {
    final isCardioDay = dayIndex % 2 != 0;
    if (isGym) {
      return isCardioDay ? _gymSeniorCardio : _gymSeniorFull;
    }
    return isCardioDay ? _homeSeniorCardio : _homeSeniorFull;
  }

  static const _gymSeniorFull = [
    {'name': 'Prensa de piernas (bajo peso, rango completo)', 'muscle_group': 'Piernas', 'sets': 3, 'reps': '12-15', 'rest_seconds': 90},
    {'name': 'Remo en máquina sentado', 'muscle_group': 'Espalda', 'sets': 3, 'reps': '12-15', 'rest_seconds': 90},
    {'name': 'Press de pecho en máquina sentado', 'muscle_group': 'Pecho', 'sets': 3, 'reps': '12-15', 'rest_seconds': 90},
    {'name': 'Extensión de cuádriceps en máquina', 'muscle_group': 'Cuádriceps', 'sets': 3, 'reps': '12-15', 'rest_seconds': 90},
    {'name': 'Elevación de talones sentado en máquina', 'muscle_group': 'Pantorrillas', 'sets': 3, 'reps': '15', 'rest_seconds': 60},
    {'name': 'Caminata en cinta 10 min ritmo suave', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '10 min', 'rest_seconds': 0},
  ];

  static const _gymSeniorCardio = [
    {'name': 'Bicicleta estática ritmo suave', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '20 min', 'rest_seconds': 0},
    {'name': 'Caminata en cinta ritmo moderado', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '15 min', 'rest_seconds': 0},
    {'name': 'Equilibrio monopodal junto a la máquina', 'muscle_group': 'Equilibrio', 'sets': 3, 'reps': '20s por lado', 'rest_seconds': 30},
    {'name': 'Estiramientos y movilidad articular', 'muscle_group': 'Movilidad', 'sets': 1, 'reps': '10 min', 'rest_seconds': 0},
  ];

  static const _homeSeniorFull = [
    {'name': 'Sentarse y levantarse de la silla', 'muscle_group': 'Piernas', 'sets': 3, 'reps': '10-12', 'rest_seconds': 90},
    {'name': 'Flexiones de pared', 'muscle_group': 'Pecho / Hombros', 'sets': 3, 'reps': '10-15', 'rest_seconds': 90},
    {'name': 'Puente de glúteos en suelo', 'muscle_group': 'Glúteos', 'sets': 3, 'reps': '12', 'rest_seconds': 90},
    {'name': 'Elevación de talones de pie junto a silla', 'muscle_group': 'Pantorrillas', 'sets': 3, 'reps': '15', 'rest_seconds': 60},
    {'name': 'Rotaciones de hombros con brazos extendidos', 'muscle_group': 'Movilidad', 'sets': 2, 'reps': '10 por dirección', 'rest_seconds': 30},
    {'name': 'Marcha en el lugar', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '5 min', 'rest_seconds': 0},
  ];

  static const _homeSeniorCardio = [
    {'name': 'Caminata suave 20-30 min (al aire libre o en casa)', 'muscle_group': 'Cardio', 'sets': 1, 'reps': '20-30 min', 'rest_seconds': 0},
    {'name': 'Equilibrio monopodal junto a una silla', 'muscle_group': 'Equilibrio', 'sets': 3, 'reps': '20s por lado', 'rest_seconds': 30},
    {'name': 'Estiramientos suaves de piernas y espalda', 'muscle_group': 'Movilidad', 'sets': 1, 'reps': '10 min', 'rest_seconds': 0},
    {'name': 'Respiración profunda y relajación', 'muscle_group': 'Bienestar', 'sets': 1, 'reps': '5 min', 'rest_seconds': 0},
  ];

  // ── ALIMENTACIÓN ───────────────────────────────────────────────────────────

  /// Genera el plan alimenticio.
  ///
  /// [userId] y [weekIndex] son la base de la variación determinista:
  /// dos usuarios distintos obtienen planes distintos; el mismo usuario obtiene
  /// el mismo plan dentro de la misma semana y un plan renovado cada semana.
  /// [dislikedFoods] y [cookingTime] usan los catálogos del nuevo onboarding
  /// (ver [OnboardingCatalogs]). El método tolera valores legacy.
  static Map<String, dynamic> generateMealPlan({
    required String goal,
    required String gender,
    required double weightKg,
    int age = 30,
    double heightCm = 170.0,
    double targetWeightKg = 0,
    int trainingDaysPerWeek = 3,
    String dailyActivityLevel = DailyActivityLevel.moderate,
    String mealsPerDay = '3',
    List<String> foodPreferences = const [],
    List<String> allergies = const [],
    List<String> dislikedFoods = const [],
    String? cookingTime,
    String? userId,
    int weekIndex = 0,
    int dayIndex = 0,
    bool eatingDisorderRisk = false,
  }) {
    // Safety override silencioso: si hay riesgo declarado en onboarding y el
    // objetivo seria perder peso, forzamos modo mantenimiento para no
    // prescribir deficit. No se etiqueta al usuario.
    final upperGoal = goal.toUpperCase();
    final effectiveGoal =
        (eatingDisorderRisk && (upperGoal == 'LOSE_WEIGHT' || upperGoal == 'CUTTING'))
            ? 'MAINTAIN'
            : upperGoal;
    final isLose = effectiveGoal == 'LOSE_WEIGHT';
    final isGain = effectiveGoal == 'GAIN_MUSCLE';
    final isFemale = gender.toUpperCase() == 'FEMALE';

    final effectiveTarget = targetWeightKg > 0 ? targetWeightKg : weightKg;

    final pref = _dominantPref(foodPreferences);

    final nutrition = NutritionCalculator.calculate(
      gender: gender,
      age: age,
      weightKg: weightKg,
      heightCm: heightCm,
      targetWeightKg: effectiveTarget,
      fitnessGoal: effectiveGoal,
      trainingDaysPerWeek: trainingDaysPerWeek,
      dailyActivityLevel: dailyActivityLevel,
      dietPref: pref,
      eatingDisorderRisk: eatingDisorderRisk,
    );

    final seed = _userSeed(userId, weekIndex);

    var items = _buildMeals(
      mealsPerDay: mealsPerDay,
      pref: pref,
      isLose: isLose,
      isGain: isGain,
      isFemale: isFemale,
      totalCalories: nutrition.recommendedCalories,
      seed: seed,
      dayIndex: dayIndex,
      cookingTime: cookingTime,
    );

    // Filtros: primero alergias (riesgo de salud), luego alimentos no deseados.
    final effectiveAllergies = allergies
        .where((a) => a != 'vegano' && a != 'vegetariano' &&
                       a != 'vegan'  && a != 'vegetarian' &&
                       a != 'ninguna' && a != 'none' && a != 'otro')
        .toList();
    if (effectiveAllergies.isNotEmpty) {
      items = _filterAllergies(items, effectiveAllergies);
    }

    final cleanedDislikes = dislikedFoods
        .where((d) => d.isNotEmpty && !d.startsWith('custom:'))
        .toList();
    if (cleanedDislikes.isNotEmpty) {
      items = _filterDislikedFoods(items, cleanedDislikes);
    }

    return {
      'title': 'Plan ${_goalLabel(goal)} — ${_prefLabel(pref)}',
      'food_mode': pref,
      'total_calories': nutrition.recommendedCalories,
      'maintenance_calories': nutrition.maintenanceCalories,
      'bmr': nutrition.bmr,
      'calorie_adjustment': nutrition.calorieAdjustment,
      'goal_interpretation': nutrition.goalInterpretation,
      'strategy': nutrition.strategy,
      'explanation_text': nutrition.explanationText,
      'protein_grams': nutrition.proteinGrams,
      'carbs_grams': nutrition.carbsGrams,
      'fats_grams': nutrition.fatsGrams,
      'disclaimer': disclaimer,
      'week_index': weekIndex,
      'cooking_time': cookingTime,
      'items': items,
    };
  }

  /// Hash determinista combinando usuario + semana. Garantiza:
  /// (a) usuarios distintos → planes distintos;
  /// (b) mismo usuario, misma semana → plan estable;
  /// (c) semana nueva → rotación garantizada.
  static int _userSeed(String? userId, int weekIndex) {
    final base = (userId == null || userId.isEmpty)
        ? 'anon'.hashCode
        : userId.hashCode;
    return ((base.abs() * 1315423911) ^ (weekIndex * 2654435761)) & 0x7fffffff;
  }

  /// Reduce las preferencias seleccionadas a un único "modo" interno.
  /// Acepta tanto los valores nuevos del onboarding (vegan, vegetarian,
  /// low_carb, high_protein, keto, omnivore, no_preference) como los legacy
  /// (vegana, vegetariana, lowcarb, proteica).
  /// Versión pública para que otros generadores (DbMealPlanGenerator) reutilicen
  /// la misma normalización de preferencia de dieta.
  static String dominantDietPref(List<String> prefs) => _dominantPref(prefs);

  static String _dominantPref(List<String> prefs) {
    if (prefs.isEmpty) return 'normal';
    final normalized = prefs.map((p) => p.toLowerCase()).toSet();

    bool has(List<String> aliases) => aliases.any(normalized.contains);

    if (has(['vegan', 'vegana'])) return 'vegana';
    if (has(['vegetarian', 'vegetariana'])) return 'vegetariana';
    if (has(['keto', 'low_carb', 'lowcarb'])) return 'lowcarb';
    if (has(['high_protein', 'proteica'])) return 'proteica';
    return 'normal';
  }

  static String _goalLabel(String g) {
    switch (g.toUpperCase()) {
      case 'LOSE_WEIGHT': return 'Pérdida de grasa';
      case 'GAIN_MUSCLE': return 'Ganancia muscular';
      default: return 'Mantenimiento';
    }
  }

  static String _prefLabel(String p) {
    switch (p) {
      case 'vegana': return 'Vegano';
      case 'vegetariana': return 'Vegetariano';
      case 'lowcarb': return 'Bajo en carbos';
      case 'proteica': return 'Alto en proteína';
      default: return 'Balanceado';
    }
  }

  static List<Map<String, dynamic>> _buildMeals({
    required String mealsPerDay,
    required String pref,
    required bool isLose,
    required bool isGain,
    required bool isFemale,
    required int totalCalories,
    required int seed,
    int dayIndex = 0,
    String? cookingTime,
  }) {
    // Acepta 'ayuno' (legacy) e 'intermittent_fasting' (nuevo onboarding).
    switch (mealsPerDay) {
      case '2':
        return _meals2(pref, isLose: isLose, isGain: isGain,
            seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
      case 'ayuno':
      case 'intermittent_fasting':
        return _mealsAyuno(pref, isLose: isLose, isGain: isGain,
            seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
      case '4':
        return _meals4(pref, isLose: isLose, isGain: isGain,
            seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
      case '5':
        return _meals5(pref, isLose: isLose, isGain: isGain,
            seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
      default: // '3' y 'flexible'
        return _meals3(pref, isLose: isLose, isGain: isGain,
            seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
    }
  }

  // ── 3 comidas — mix & match entre planes según semilla + día ──────────────

  /// Para multiplicar variedad sin escribir más planes: cada comida
  /// (desayuno/almuerzo/cena) se elige por separado entre los planes
  /// disponibles. Con 4 planes da 4^3 = 64 combinaciones por preferencia,
  /// y cada día rota a otra combinación distinta. Si el usuario tiene
  /// poco tiempo para cocinar, restringimos a los planes más simples.
  static List<Map<String, dynamic>> _meals3(
    String pref, {
    required bool isLose,
    required bool isGain,
    required int seed,
    int dayIndex = 0,
    String? cookingTime,
  }) {
    final plans = _meals3Plans(pref, isLose: isLose, isGain: isGain);
    final pool = _cookingTimeBias(plans.length, cookingTime);

    Map<String, dynamic> pick(int planIdx, String type) {
      final plan = plans[planIdx];
      final found = plan.firstWhere(
        (m) => m['meal_type'] == type,
        orElse: () => plan.first,
      );
      return Map<String, dynamic>.from(found);
    }

    final iB = pool[(seed + dayIndex * 7) % pool.length];
    final iL = pool[(seed + dayIndex * 11 + 1) % pool.length];
    final iD = pool[(seed + dayIndex * 13 + 2) % pool.length];

    return [
      pick(iB, 'breakfast'),
      pick(iL, 'lunch'),
      pick(iD, 'dinner'),
    ];
  }

  /// Sesgo según tiempo de cocina. Por convención los planes se escriben
  /// ordenados de más simple a más elaborado, así que limitar el rango de
  /// `pool` actúa como un filtro de complejidad sin necesidad de tagging.
  /// IMPORTANTE: el pool mínimo es 3 para garantizar variedad entre usuarios
  /// incluso en el caso restrictivo. Con 3 planes y 3 slots (B/L/D) hay
  /// 27 combinaciones por preferencia, así que dos usuarios distintos
  /// tienen ~96% de probabilidad de recibir comidas distintas.
  ///   no_time          → primeros 3 planes (los más simples)
  ///   quick_lt_15m     → primeros 4 planes
  ///   medium_15_30m    → primeros 5 planes
  ///   enjoy_cooking    → todos los planes disponibles
  static List<int> _cookingTimeBias(int total, String? cookingTime) {
    if (total <= 1) return [0];
    int cap;
    switch (cookingTime) {
      case 'no_time':
        cap = 3;
        break;
      case 'quick_lt_15m':
        cap = 4;
        break;
      case 'medium_15_30m':
        cap = 5;
        break;
      case 'enjoy_cooking':
      default:
        cap = total;
    }
    if (cap > total) cap = total;
    if (cap < 1) cap = 1;
    return List.generate(cap, (i) => i);
  }

  static List<List<Map<String, dynamic>>> _meals3Plans(String pref, {required bool isLose, required bool isGain}) {
    switch (pref) {
      case 'vegetariana':
        return [
          [
            {'meal_type': 'breakfast', 'name': 'Tostadas integrales con huevo y aguacate', 'ingredients': ['2 rebanadas pan integral', '2 huevos', '½ aguacate', 'tomate'], 'calories': isGain ? 420 : 320, 'protein': 18.0, 'carbs': isGain ? 40.0 : 30.0, 'fats': 14.0},
            {'meal_type': 'lunch', 'name': 'Bowl de quinoa con garbanzos y vegetales', 'ingredients': ['150g quinoa', '100g garbanzos', 'espinaca', 'pimiento', 'aceite de oliva'], 'calories': isGain ? 600 : 450, 'protein': 22.0, 'carbs': isGain ? 75.0 : 55.0, 'fats': 12.0},
            {'meal_type': 'dinner', 'name': 'Tortilla de vegetales con ensalada', 'ingredients': ['3 huevos', 'calabacín', 'cebolla', 'queso cottage', 'ensalada verde'], 'calories': isLose ? 300 : 420, 'protein': 24.0, 'carbs': 15.0, 'fats': 18.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Yogur griego con granola y frutos rojos', 'ingredients': ['200g yogur griego', '40g granola sin azúcar', 'frutos rojos', '1 cda miel'], 'calories': isGain ? 400 : 290, 'protein': 16.0, 'carbs': isGain ? 52.0 : 38.0, 'fats': 8.0},
            {'meal_type': 'lunch', 'name': 'Curry de lentejas rojas con arroz basmati', 'ingredients': ['200g lentejas', '100g arroz basmati', 'leche de coco', 'curry', 'cebolla', 'tomate'], 'calories': isGain ? 620 : 460, 'protein': 24.0, 'carbs': isGain ? 80.0 : 60.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Calabaza rellena de queso y espinacas', 'ingredients': ['1 calabaza mediana', '100g queso ricotta', 'espinaca', 'nuez moscada', 'aceite de oliva'], 'calories': isLose ? 280 : 400, 'protein': 18.0, 'carbs': 22.0, 'fats': 14.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Pancakes de avena con miel y plátano', 'ingredients': ['80g avena', '2 huevos', '1 plátano', '1 cda miel', 'canela'], 'calories': isGain ? 450 : 330, 'protein': 18.0, 'carbs': isGain ? 65.0 : 48.0, 'fats': 9.0},
            {'meal_type': 'lunch', 'name': 'Pasta integral con salsa de tomate y queso', 'ingredients': ['200g pasta integral', 'salsa de tomate natural', '80g queso mozzarella', 'albahaca', 'aceite de oliva'], 'calories': isGain ? 640 : 480, 'protein': 26.0, 'carbs': isGain ? 78.0 : 58.0, 'fats': 14.0},
            {'meal_type': 'dinner', 'name': 'Ensalada de garbanzos con feta y pepino', 'ingredients': ['150g garbanzos cocidos', '60g queso feta', 'pepino', 'tomate cherry', 'aceitunas', 'limón'], 'calories': isLose ? 310 : 430, 'protein': 20.0, 'carbs': 28.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Revuelto de huevos con champiñones y espinaca', 'ingredients': ['3 huevos', '100g champiñones', 'espinaca', 'queso parmesano', 'aceite de oliva'], 'calories': isGain ? 430 : 310, 'protein': 26.0, 'carbs': 8.0, 'fats': 20.0},
            {'meal_type': 'lunch', 'name': 'Buddha bowl de boniato, garbanzos y tahini', 'ingredients': ['150g boniato asado', '120g garbanzos', 'col lombarda', 'tahini', 'limón', 'perejil'], 'calories': isGain ? 590 : 440, 'protein': 18.0, 'carbs': isGain ? 72.0 : 54.0, 'fats': 16.0},
            {'meal_type': 'dinner', 'name': 'Sopa de tomate con tostadas de queso', 'ingredients': ['400g tomate triturado', '1 cebolla', 'ajo', '2 rebanadas pan integral', '60g queso manchego'], 'calories': isLose ? 290 : 400, 'protein': 16.0, 'carbs': 32.0, 'fats': 14.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Huevos al horno con tomate y feta (shakshuka)', 'ingredients': ['2 huevos', '200g tomate triturado', '50g queso feta', 'pimiento', 'cebolla', 'comino'], 'calories': isGain ? 440 : 320, 'protein': 22.0, 'carbs': 18.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Risotto de champiñones y queso parmesano', 'ingredients': ['150g arroz arborio', '200g champiñones', '60g parmesano', 'caldo vegetal', 'cebolla', 'mantequilla'], 'calories': isGain ? 620 : 470, 'protein': 22.0, 'carbs': isGain ? 78.0 : 60.0, 'fats': 14.0},
            {'meal_type': 'dinner', 'name': 'Wrap de hummus con vegetales y queso de cabra', 'ingredients': ['1 tortilla integral grande', '60g hummus', '50g queso de cabra', 'rúcula', 'pepino', 'tomate'], 'calories': isLose ? 320 : 430, 'protein': 18.0, 'carbs': 38.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tortilla francesa con queso y pan integral', 'ingredients': ['2 huevos', '40g queso emmental', '1 rebanada pan integral', 'mantequilla'], 'calories': isGain ? 410 : 300, 'protein': 24.0, 'carbs': 18.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Estofado de seitán con patatas y zanahoria', 'ingredients': ['180g seitán', '120g patata', 'zanahoria', 'cebolla', 'tomate', 'pimentón'], 'calories': isGain ? 600 : 450, 'protein': 38.0, 'carbs': isGain ? 60.0 : 44.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Pizza casera de espinaca y ricotta', 'ingredients': ['1 base pizza integral', '80g ricotta', 'espinaca fresca', '40g mozzarella', 'tomate', 'orégano'], 'calories': isLose ? 360 : 500, 'protein': 22.0, 'carbs': 48.0, 'fats': 16.0},
          ],
        ];

      case 'vegana':
        return [
          [
            {'meal_type': 'breakfast', 'name': 'Bowl de avena con frutas y semillas de chía', 'ingredients': ['80g avena', 'leche de avena', 'plátano', 'frutos rojos', '1 cda chía'], 'calories': isGain ? 450 : 320, 'protein': 12.0, 'carbs': isGain ? 70.0 : 50.0, 'fats': 8.0},
            {'meal_type': 'lunch', 'name': 'Lentejas con arroz integral y espinacas', 'ingredients': ['200g lentejas', '100g arroz integral', 'espinaca', 'cúrcuma', 'aceite de oliva'], 'calories': isGain ? 620 : 450, 'protein': 24.0, 'carbs': isGain ? 80.0 : 60.0, 'fats': 8.0},
            {'meal_type': 'dinner', 'name': 'Tofu salteado con quinoa y brócoli', 'ingredients': ['150g tofu firme', '100g quinoa', 'brócoli', 'salsa de soja', 'aceite de sésamo'], 'calories': isLose ? 350 : 480, 'protein': 22.0, 'carbs': 40.0, 'fats': 12.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tostadas de aguacate con semillas de girasol', 'ingredients': ['2 rebanadas pan integral', '1 aguacate', 'semillas de girasol', 'limón', 'pimentón'], 'calories': isGain ? 440 : 320, 'protein': 10.0, 'carbs': isGain ? 45.0 : 35.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Curry de garbanzos con coco y arroz', 'ingredients': ['200g garbanzos', '100g arroz', 'leche de coco', 'curry en polvo', 'espinaca', 'cebolla'], 'calories': isGain ? 640 : 470, 'protein': 20.0, 'carbs': isGain ? 82.0 : 62.0, 'fats': 14.0},
            {'meal_type': 'dinner', 'name': 'Bowl de soja con quinoa y semillas', 'ingredients': ['120g soja cocida', '100g quinoa', 'pepino', 'zanahoria', 'semillas de sésamo', 'salsa de soja'], 'calories': isLose ? 340 : 460, 'protein': 24.0, 'carbs': 42.0, 'fats': 10.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Smoothie bowl de mango con granola vegana', 'ingredients': ['150g mango', '80g plátano congelado', '40g granola vegana', 'semillas de cáñamo', 'leche de almendra'], 'calories': isGain ? 480 : 340, 'protein': 10.0, 'carbs': isGain ? 72.0 : 54.0, 'fats': 10.0},
            {'meal_type': 'lunch', 'name': 'Tacos de soya texturizada con guacamole', 'ingredients': ['150g soya texturizada hidratada', '3 tortillas maíz', '1 aguacate', 'pico de gallo', 'lima', 'cilantro'], 'calories': isGain ? 610 : 460, 'protein': 28.0, 'carbs': isGain ? 68.0 : 50.0, 'fats': 18.0},
            {'meal_type': 'dinner', 'name': 'Crema de calabaza con pan de semillas', 'ingredients': ['400g calabaza', 'leche de coco', 'jengibre', 'cúrcuma', '2 rebanadas pan de semillas'], 'calories': isLose ? 300 : 420, 'protein': 10.0, 'carbs': 48.0, 'fats': 12.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Porridge de mijo con frutos secos', 'ingredients': ['80g mijo', 'leche de soja', '30g nueces', '1 pera', 'canela', '1 cda sirope de agave'], 'calories': isGain ? 460 : 330, 'protein': 14.0, 'carbs': isGain ? 60.0 : 44.0, 'fats': 14.0},
            {'meal_type': 'lunch', 'name': 'Ensalada de alubias negras con maíz y aguacate', 'ingredients': ['200g alubias negras', '80g maíz', '1 aguacate', 'tomate', 'cilantro', 'lima'], 'calories': isGain ? 580 : 430, 'protein': 20.0, 'carbs': isGain ? 70.0 : 52.0, 'fats': 16.0},
            {'meal_type': 'dinner', 'name': 'Pasta integral con pesto vegano de anacardos', 'ingredients': ['200g pasta integral', 'albahaca fresca', '30g anacardos', 'ajo', 'levadura nutricional', 'aceite de oliva'], 'calories': isLose ? 360 : 500, 'protein': 16.0, 'carbs': 58.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tostadas de hummus con tomate y semillas', 'ingredients': ['2 rebanadas pan integral', '60g hummus', 'tomate', '1 cda semillas de calabaza', 'orégano'], 'calories': isGain ? 430 : 310, 'protein': 14.0, 'carbs': isGain ? 50.0 : 36.0, 'fats': 14.0},
            {'meal_type': 'lunch', 'name': 'Wok de fideos soba con tofu y vegetales', 'ingredients': ['120g fideos soba', '150g tofu firme', 'pak choi', 'zanahoria', 'jengibre', 'salsa tamari'], 'calories': isGain ? 610 : 450, 'protein': 24.0, 'carbs': isGain ? 78.0 : 58.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Hamburguesa vegana de lentejas con boniato al horno', 'ingredients': ['150g lentejas cocidas', '50g avena', '150g boniato', 'cebolla', 'comino', 'mostaza'], 'calories': isLose ? 380 : 510, 'protein': 22.0, 'carbs': 60.0, 'fats': 10.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Yogur de coco con kiwi y semillas de lino', 'ingredients': ['200g yogur de coco', '1 kiwi', '1 cda semillas de lino', '20g almendras', 'canela'], 'calories': isGain ? 420 : 310, 'protein': 8.0, 'carbs': isGain ? 42.0 : 30.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Bowl mediterráneo de cuscús con falafel', 'ingredients': ['100g cuscús integral', '4 falafel', 'pepino', 'tomate cherry', 'tahini', 'limón'], 'calories': isGain ? 620 : 470, 'protein': 22.0, 'carbs': isGain ? 78.0 : 60.0, 'fats': 16.0},
            {'meal_type': 'dinner', 'name': 'Tempeh marinado con verduras al wok y arroz negro', 'ingredients': ['150g tempeh', '100g arroz negro', 'brócoli', 'pimiento', 'salsa de soja', 'aceite de sésamo'], 'calories': isLose ? 380 : 510, 'protein': 26.0, 'carbs': 52.0, 'fats': 14.0},
          ],
        ];

      case 'lowcarb':
        return [
          [
            {'meal_type': 'breakfast', 'name': 'Huevos revueltos con aguacate y salmón', 'ingredients': ['3 huevos', '½ aguacate', '80g salmón a la plancha', 'espinaca'], 'calories': isGain ? 480 : 360, 'protein': 32.0, 'carbs': 5.0, 'fats': 28.0},
            {'meal_type': 'lunch', 'name': 'Pollo a la plancha con ensalada y nueces', 'ingredients': ['200g pechuga', 'lechuga', 'tomate cherry', '30g nueces', 'aceite de oliva', 'limón'], 'calories': isGain ? 550 : 420, 'protein': 45.0, 'carbs': 10.0, 'fats': 28.0},
            {'meal_type': 'dinner', 'name': 'Salmón al horno con espárragos', 'ingredients': ['200g salmón', 'espárragos', 'limón', 'ajo', 'aceite de oliva'], 'calories': isLose ? 380 : 480, 'protein': 40.0, 'carbs': 8.0, 'fats': 22.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Omelette de queso con pavo en lonchas', 'ingredients': ['3 huevos', '50g pavo en lonchas', '40g queso manchego', 'espinaca', 'aceite de oliva'], 'calories': isGain ? 490 : 370, 'protein': 34.0, 'carbs': 3.0, 'fats': 30.0},
            {'meal_type': 'lunch', 'name': 'Ternera con brócoli y mantequilla de ajo', 'ingredients': ['200g filete de ternera', 'brócoli', 'ajo', 'mantequilla', 'romero'], 'calories': isGain ? 560 : 430, 'protein': 48.0, 'carbs': 8.0, 'fats': 26.0},
            {'meal_type': 'dinner', 'name': 'Ensalada nicoise con atún y huevo duro', 'ingredients': ['150g atún', '2 huevos duros', 'judías verdes', 'aceitunas', 'tomate', 'aceite de oliva'], 'calories': isLose ? 360 : 460, 'protein': 42.0, 'carbs': 10.0, 'fats': 20.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Yogur griego con almendras y canela', 'ingredients': ['200g yogur griego natural', '30g almendras', 'canela', '1 cda semillas de chía'], 'calories': isGain ? 400 : 290, 'protein': 22.0, 'carbs': 12.0, 'fats': 22.0},
            {'meal_type': 'lunch', 'name': 'Pavo a la plancha con calabacín y feta', 'ingredients': ['200g pechuga de pavo', '1 calabacín', '60g queso feta', 'aceite de oliva', 'orégano'], 'calories': isGain ? 520 : 400, 'protein': 48.0, 'carbs': 8.0, 'fats': 22.0},
            {'meal_type': 'dinner', 'name': 'Bacalao al horno con vegetales mediterráneos', 'ingredients': ['200g bacalao', 'pimiento', 'tomate', 'cebolla', 'aceitunas', 'aceite de oliva'], 'calories': isLose ? 340 : 440, 'protein': 38.0, 'carbs': 12.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Batido de proteína con mantequilla de almendra', 'ingredients': ['1 scoop proteína whey', '200ml leche entera', '1 cda mantequilla de almendra', 'hielo'], 'calories': isGain ? 460 : 340, 'protein': 36.0, 'carbs': 10.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Costilla de cerdo con coliflor asada', 'ingredients': ['250g costilla de cerdo', 'coliflor', 'ajo', 'pimentón', 'aceite de oliva'], 'calories': isGain ? 580 : 450, 'protein': 46.0, 'carbs': 10.0, 'fats': 28.0},
            {'meal_type': 'dinner', 'name': 'Sopa de pollo con verduras sin fideos', 'ingredients': ['150g pollo', 'apio', 'zanahoria', 'cebolla', 'ajo', 'caldo de hueso'], 'calories': isLose ? 300 : 400, 'protein': 34.0, 'carbs': 14.0, 'fats': 12.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Aguacate relleno de atún y huevo', 'ingredients': ['1 aguacate', '100g atún en agua', '1 huevo', 'cebolla morada', 'limón', 'eneldo'], 'calories': isGain ? 470 : 360, 'protein': 32.0, 'carbs': 6.0, 'fats': 28.0},
            {'meal_type': 'lunch', 'name': 'Pollo a la mantequilla con espinaca cremosa', 'ingredients': ['200g pechuga', 'espinaca', '50ml crema espesa', '30g parmesano', 'ajo', 'mantequilla'], 'calories': isGain ? 580 : 440, 'protein': 50.0, 'carbs': 6.0, 'fats': 28.0},
            {'meal_type': 'dinner', 'name': 'Albóndigas de ternera con salsa de tomate y mozzarella', 'ingredients': ['180g ternera picada', '60g mozzarella', '100g salsa de tomate natural', '1 huevo', 'orégano'], 'calories': isLose ? 360 : 470, 'protein': 42.0, 'carbs': 8.0, 'fats': 24.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Crepe keto de queso crema con jamón', 'ingredients': ['2 huevos', '40g queso crema', '60g jamón cocido', '20g queso cheddar', 'cebollino'], 'calories': isGain ? 460 : 350, 'protein': 32.0, 'carbs': 4.0, 'fats': 26.0},
            {'meal_type': 'lunch', 'name': 'Bowl césar de pollo (sin crutones)', 'ingredients': ['200g pechuga', 'lechuga romana', '30g parmesano', '4 anchoas', 'mayonesa', 'limón'], 'calories': isGain ? 560 : 430, 'protein': 48.0, 'carbs': 8.0, 'fats': 26.0},
            {'meal_type': 'dinner', 'name': 'Filete con champiñones al ajillo y mantequilla de hierbas', 'ingredients': ['220g filete', '150g champiñones', 'ajo', 'romero', 'mantequilla', 'perejil'], 'calories': isLose ? 380 : 480, 'protein': 48.0, 'carbs': 8.0, 'fats': 26.0},
          ],
        ];

      case 'proteica':
        return [
          [
            {'meal_type': 'breakfast', 'name': 'Omelette de claras con avena proteica', 'ingredients': ['5 claras', '1 yema', '60g avena', 'leche descremada', 'canela'], 'calories': isGain ? 450 : 340, 'protein': 35.0, 'carbs': isGain ? 45.0 : 35.0, 'fats': 8.0},
            {'meal_type': 'lunch', 'name': 'Pechuga de pollo con arroz y brócoli', 'ingredients': ['200g pechuga', '150g arroz blanco', 'brócoli al vapor', 'aceite de coco'], 'calories': isGain ? 650 : 480, 'protein': 55.0, 'carbs': isGain ? 65.0 : 45.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Atún con batata y espinacas salteadas', 'ingredients': ['200g atún en agua', '150g batata', 'espinaca', 'ajo', 'aceite de oliva'], 'calories': isLose ? 380 : 500, 'protein': 45.0, 'carbs': 35.0, 'fats': 8.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Batido de proteína con avena y plátano', 'ingredients': ['1 scoop proteína whey', '50g avena', '1 plátano', '200ml leche descremada'], 'calories': isGain ? 480 : 360, 'protein': 38.0, 'carbs': isGain ? 58.0 : 42.0, 'fats': 6.0},
            {'meal_type': 'lunch', 'name': 'Salmón con quinoa y espárragos', 'ingredients': ['200g salmón', '120g quinoa', 'espárragos', 'limón', 'eneldo'], 'calories': isGain ? 680 : 500, 'protein': 50.0, 'carbs': isGain ? 60.0 : 42.0, 'fats': 18.0},
            {'meal_type': 'dinner', 'name': 'Pavo picado con verduras y claras de huevo', 'ingredients': ['200g pavo picado', '4 claras', 'pimiento', 'cebolla', 'salsa de tomate natural'], 'calories': isLose ? 360 : 480, 'protein': 52.0, 'carbs': 18.0, 'fats': 8.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Cottage con frutas y granola proteica', 'ingredients': ['200g queso cottage', '1 plátano', '30g granola proteica', 'canela'], 'calories': isGain ? 430 : 320, 'protein': 30.0, 'carbs': isGain ? 48.0 : 34.0, 'fats': 6.0},
            {'meal_type': 'lunch', 'name': 'Ternera magra con pasta integral y tomate', 'ingredients': ['180g ternera magra', '150g pasta integral', 'salsa de tomate', 'albahaca'], 'calories': isGain ? 660 : 490, 'protein': 52.0, 'carbs': isGain ? 68.0 : 50.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Merluza al vapor con batata y judías', 'ingredients': ['200g merluza', '100g batata', '100g judías verdes', 'limón', 'aceite de oliva'], 'calories': isLose ? 350 : 470, 'protein': 44.0, 'carbs': 30.0, 'fats': 8.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tostadas con claras de huevo y jamón', 'ingredients': ['2 rebanadas pan integral', '4 claras de huevo', '60g jamón cocido', 'tomate', 'aceite de oliva'], 'calories': isGain ? 460 : 340, 'protein': 36.0, 'carbs': isGain ? 42.0 : 30.0, 'fats': 8.0},
            {'meal_type': 'lunch', 'name': 'Pollo al curry con arroz basmati y guisantes', 'ingredients': ['200g pechuga', '150g arroz basmati', '80g guisantes', 'curry', 'cebolla', 'yogur'], 'calories': isGain ? 640 : 470, 'protein': 54.0, 'carbs': isGain ? 66.0 : 46.0, 'fats': 9.0},
            {'meal_type': 'dinner', 'name': 'Lubina a la plancha con ensalada de rúcula', 'ingredients': ['200g lubina', 'rúcula', 'tomate cherry', 'parmesano', 'aceite de oliva', 'limón'], 'calories': isLose ? 340 : 460, 'protein': 42.0, 'carbs': 8.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tortilla de claras con avena dulce', 'ingredients': ['5 claras', '60g avena', '200ml leche descremada', 'canela', '1 cda miel'], 'calories': isGain ? 460 : 340, 'protein': 32.0, 'carbs': isGain ? 56.0 : 42.0, 'fats': 6.0},
            {'meal_type': 'lunch', 'name': 'Solomillo de cerdo con quinoa y verduras', 'ingredients': ['200g solomillo de cerdo', '120g quinoa', 'pimiento', 'calabacín', 'aceite de oliva'], 'calories': isGain ? 640 : 470, 'protein': 50.0, 'carbs': isGain ? 60.0 : 42.0, 'fats': 12.0},
            {'meal_type': 'dinner', 'name': 'Brochetas de pavo y vegetales con bulgur', 'ingredients': ['200g pavo en cubos', 'pimiento', 'cebolla', 'calabacín', '100g bulgur', 'limón'], 'calories': isLose ? 360 : 470, 'protein': 48.0, 'carbs': 38.0, 'fats': 8.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Bowl proteico de skyr con frutos rojos', 'ingredients': ['200g skyr natural', '30g granola proteica', 'frutos rojos', '1 cda miel'], 'calories': isGain ? 430 : 320, 'protein': 34.0, 'carbs': isGain ? 48.0 : 34.0, 'fats': 6.0},
            {'meal_type': 'lunch', 'name': 'Lomo de cerdo magro con arroz y judías verdes', 'ingredients': ['200g lomo de cerdo magro', '150g arroz', '120g judías verdes', 'ajo', 'aceite de oliva'], 'calories': isGain ? 660 : 490, 'protein': 52.0, 'carbs': isGain ? 64.0 : 46.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Tartar de atún con aguacate y arroz integral', 'ingredients': ['180g atún fresco', '½ aguacate', '100g arroz integral', 'salsa de soja', 'sésamo', 'lima'], 'calories': isLose ? 380 : 500, 'protein': 44.0, 'carbs': 40.0, 'fats': 12.0},
          ],
        ];

      default: // normal
        return [
          [
            {'meal_type': 'breakfast', 'name': 'Avena con plátano y huevos revueltos', 'ingredients': ['80g avena', '200ml leche', '1 plátano', '2 huevos'], 'calories': isGain ? 480 : 350, 'protein': 22.0, 'carbs': isGain ? 70.0 : 50.0, 'fats': 10.0},
            {'meal_type': 'lunch', 'name': 'Pollo a la plancha con arroz y ensalada', 'ingredients': ['180g pechuga', '150g arroz', 'ensalada verde', 'aceite de oliva'], 'calories': isGain ? 620 : 460, 'protein': 42.0, 'carbs': isGain ? 68.0 : 48.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': isLose ? 'Salmón al horno con verduras' : 'Pasta integral con atún', 'ingredients': isLose ? ['160g salmón', 'brócoli', 'zanahoria', 'aceite oliva'] : ['200g pasta integral', '150g atún', 'tomate cherry', 'albahaca'], 'calories': isLose ? 360 : 520, 'protein': 36.0, 'carbs': isLose ? 12.0 : 58.0, 'fats': 14.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tostadas con aguacate, tomate y huevo poché', 'ingredients': ['2 rebanadas pan integral', '½ aguacate', 'tomate', '2 huevos pochados', 'sal', 'pimienta'], 'calories': isGain ? 460 : 340, 'protein': 20.0, 'carbs': isGain ? 42.0 : 30.0, 'fats': 18.0},
            {'meal_type': 'lunch', 'name': 'Lentejas estofadas con chorizo y pan', 'ingredients': ['200g lentejas', '60g chorizo bajo en grasa', 'zanahoria', 'pimiento', 'cebolla', '1 rebanada pan'], 'calories': isGain ? 640 : 470, 'protein': 32.0, 'carbs': isGain ? 72.0 : 54.0, 'fats': 14.0},
            {'meal_type': 'dinner', 'name': 'Pechuga de pollo con puré de coliflor', 'ingredients': ['180g pechuga', '300g coliflor', 'leche', 'mantequilla', 'ajo'], 'calories': isLose ? 330 : 460, 'protein': 40.0, 'carbs': 18.0, 'fats': 12.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Huevos fritos o revueltos con tostadas', 'ingredients': ['2-3 huevos', '2 tostadas con mantequilla', 'café o té', 'zumo de naranja (opcional)'], 'calories': isGain ? 480 : 340, 'protein': 20.0, 'carbs': isGain ? 48.0 : 34.0, 'fats': 16.0},
            {'meal_type': 'lunch', 'name': 'Pisto con huevos y pan', 'ingredients': ['calabacín', 'pimiento', 'tomate', 'cebolla', '3 huevos', '2 rebanadas pan'], 'calories': isGain ? 580 : 430, 'protein': 24.0, 'carbs': isGain ? 62.0 : 46.0, 'fats': 18.0},
            {'meal_type': 'dinner', 'name': 'Merluza o pescado blanco con patatas', 'ingredients': ['200g merluza o similar', '120g patata cocida', 'perejil', 'ajo', 'aceite de oliva'], 'calories': isLose ? 320 : 450, 'protein': 38.0, 'carbs': 28.0, 'fats': 10.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Yogur griego con nueces y miel', 'ingredients': ['200g yogur griego', '25g nueces', '1 cda miel', '1 manzana'], 'calories': isGain ? 420 : 300, 'protein': 18.0, 'carbs': isGain ? 46.0 : 34.0, 'fats': 14.0},
            {'meal_type': 'lunch', 'name': 'Arroz integral con salmón y aguacate', 'ingredients': ['150g arroz integral', '180g salmón a la plancha', '½ aguacate', 'sésamo', 'salsa de soja'], 'calories': isGain ? 660 : 490, 'protein': 40.0, 'carbs': isGain ? 70.0 : 52.0, 'fats': 20.0},
            {'meal_type': 'dinner', 'name': 'Ensalada César con pechuga y crutones', 'ingredients': ['150g pechuga a la plancha', 'lechuga romana', '20g parmesano', 'crutones integrales', 'salsa César ligera'], 'calories': isLose ? 340 : 470, 'protein': 38.0, 'carbs': 22.0, 'fats': 14.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Bowl de skyr con manzana, canela y almendras', 'ingredients': ['200g skyr', '1 manzana', '20g almendras', 'canela', '1 cda miel'], 'calories': isGain ? 430 : 320, 'protein': 26.0, 'carbs': isGain ? 50.0 : 36.0, 'fats': 10.0},
            {'meal_type': 'lunch', 'name': 'Salteado de ternera con verduras y arroz frito', 'ingredients': ['180g ternera magra', '150g arroz', 'pimiento', 'cebolla', 'zanahoria', 'salsa de soja', 'sésamo'], 'calories': isGain ? 640 : 480, 'protein': 40.0, 'carbs': isGain ? 70.0 : 52.0, 'fats': 14.0},
            {'meal_type': 'dinner', 'name': 'Pollo asado con boniato y judías verdes', 'ingredients': ['200g muslo de pollo deshuesado', '150g boniato', 'judías verdes', 'romero', 'aceite de oliva'], 'calories': isLose ? 380 : 510, 'protein': 38.0, 'carbs': 38.0, 'fats': 16.0},
          ],
          [
            {'meal_type': 'breakfast', 'name': 'Tortitas de avena y plátano con yogur', 'ingredients': ['60g avena', '1 plátano', '2 huevos', '150g yogur griego', 'canela'], 'calories': isGain ? 460 : 340, 'protein': 24.0, 'carbs': isGain ? 56.0 : 42.0, 'fats': 10.0},
            {'meal_type': 'lunch', 'name': 'Paella de mariscos exprés', 'ingredients': ['150g arroz', '120g mezcla de mariscos', '50g guisantes', 'pimiento', 'azafrán', 'caldo de pescado'], 'calories': isGain ? 620 : 460, 'protein': 32.0, 'carbs': isGain ? 70.0 : 52.0, 'fats': 10.0},
            {'meal_type': 'dinner', 'name': 'Hamburguesa casera de pavo con boniato al horno', 'ingredients': ['180g pavo picado', '1 pan de hamburguesa integral', '150g boniato', 'lechuga', 'tomate', 'mostaza'], 'calories': isLose ? 380 : 520, 'protein': 42.0, 'carbs': 50.0, 'fats': 12.0},
          ],
        ];
    }
  }

  // ── 2 comidas ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _scaleItem(Map<String, dynamic> item, double factor, String nameSuffix) {
    return {
      ...item,
      'name': '${item['name']} $nameSuffix',
      'calories': ((item['calories'] as int) * factor).toInt(),
      'protein': ((item['protein'] as double) * factor),
      'carbs': ((item['carbs'] as double) * factor),
      'fats': ((item['fats'] as double) * factor),
    };
  }

  static List<Map<String, dynamic>> _meals2(String pref, {required bool isLose, required bool isGain, required int seed, int dayIndex = 0, String? cookingTime}) {
    final base = _meals3(pref, isLose: isLose, isGain: isGain, seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
    final lunch = base.firstWhere((m) => m['meal_type'] == 'lunch');
    final dinner = base.firstWhere((m) => m['meal_type'] == 'dinner');
    return [
      _scaleItem(lunch, 1.35, '(porción amplia)'),
      _scaleItem(dinner, 1.35, '(porción amplia)'),
    ];
  }

  // ── Ayuno intermitente (ventana 12-20h) ───────────────────────────────────

  static List<Map<String, dynamic>> _mealsAyuno(String pref, {required bool isLose, required bool isGain, required int seed, int dayIndex = 0, String? cookingTime}) {
    final base = _meals3(pref, isLose: isLose, isGain: isGain, seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
    final lunch = base.firstWhere((m) => m['meal_type'] == 'lunch');
    final dinner = base.firstWhere((m) => m['meal_type'] == 'dinner');
    return [
      {
        'meal_type': 'lunch',
        'name': '12:00 — ${lunch['name']} (porción amplia)',
        'ingredients': lunch['ingredients'],
        'calories': ((lunch['calories'] as int) * 1.3).toInt(),
        'protein': (lunch['protein'] as double) * 1.3,
        'carbs': (lunch['carbs'] as double) * 1.3,
        'fats': (lunch['fats'] as double) * 1.3,
      },
      {'meal_type': 'snack', 'name': '16:00 — Snack proteico', 'ingredients': ['150g yogur griego', 'fruta de temporada'], 'calories': 180, 'protein': 12.0, 'carbs': 18.0, 'fats': 2.0},
      {'meal_type': 'dinner', 'name': '19:30 — ${dinner['name']}', 'ingredients': dinner['ingredients'], 'calories': dinner['calories'], 'protein': dinner['protein'], 'carbs': dinner['carbs'], 'fats': dinner['fats']},
    ];
  }

  // ── 4 comidas ─────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _meals4(String pref, {required bool isLose, required bool isGain, required int seed, int dayIndex = 0, String? cookingTime}) {
    final base = _meals3(pref, isLose: isLose, isGain: isGain, seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
    final snack = {
      'meal_type': 'snack',
      'name': isGain ? 'Batido de proteína con plátano y mantequilla de maní' : 'Yogur griego con frutos rojos',
      'ingredients': isGain ? ['1 scoop proteína', '1 plátano', '1 cda mantequilla de maní', '200ml leche'] : ['150g yogur griego', 'frutos rojos', '1 cda miel'],
      'calories': isGain ? 380 : 160,
      'protein': isGain ? 30.0 : 12.0,
      'carbs': isGain ? 42.0 : 16.0,
      'fats': isGain ? 10.0 : 2.0,
    };
    return [...base, snack];
  }

  // ── 5+ comidas ────────────────────────────────────────────────────────────

  // Acepta tanto nombres del nuevo onboarding (lactose, gluten, nuts, seafood,
  // egg, soy) como los legacy en español. Mapean al mismo set de keywords.
  static const Map<String, List<String>> _allergenKeywords = {
    // Nuevos (onboarding actual)
    'lactose':      ['leche', 'queso', 'yogur', 'yogurt', 'mantequilla', 'crema', 'whey', 'ricotta', 'cottage', 'feta', 'mozzarella', 'parmesano', 'gruyère', 'manchego'],
    'nuts':         ['nueces', 'almendras', 'anacardos', 'avellanas', 'pistachos', 'mantequilla de almendra', 'mantequilla de maní', 'mantequilla de mani', 'cajuil', 'maranon', 'frutos secos'],
    'seafood':      ['camarón', 'langostino', 'mejillón', 'almeja', 'calamar', 'pulpo', 'marisco', 'langosta', 'ostión', 'atún', 'salmón', 'merluza', 'bacalao', 'lubina', 'atun', 'salmon'],
    'egg':          ['huevo', 'huevos', 'claras', 'yema'],
    'soy':          ['soja', 'soya', 'tofu', 'tempeh', 'edamame', 'leche de soja'],
    // Legacy (registros previos al cambio de onboarding)
    'lactosa':      ['leche', 'queso', 'yogur', 'yogurt', 'mantequilla', 'crema', 'whey', 'ricotta', 'cottage', 'feta', 'mozzarella', 'parmesano', 'gruyère', 'manchego'],
    'frutos_secos': ['nueces', 'almendras', 'anacardos', 'avellanas', 'pistachos', 'mantequilla de almendra', 'mantequilla de maní', 'mantequilla de mani', 'cajuil', 'maranon', 'frutos secos'],
    'mariscos':     ['camarón', 'langostino', 'mejillón', 'almeja', 'calamar', 'pulpo', 'marisco', 'langosta', 'ostión', 'atún', 'salmón', 'merluza', 'bacalao', 'lubina', 'atun', 'salmon'],
    'huevo':        ['huevo', 'huevos', 'claras', 'yema'],
    'soja':         ['soja', 'soya', 'tofu', 'tempeh', 'edamame', 'leche de soja'],
    // Compartido (siempre el mismo término)
    'gluten':       ['pan', 'pasta', 'harina', 'avena', 'granola', 'crutones', 'trigo', 'espelta', 'cebada', 'centeno', 'tostadas', 'rebanadas'],
  };

  // Mapa de "alimentos no deseados" (catálogo `dislikedFoodsCommon` del onboarding).
  // Cada key del catálogo se traduce a las palabras que aparecen realmente en
  // los ingredientes de los planes. Si el ítem contiene uno de estos términos
  // se marca para que el usuario sepa que debe sustituirlo.
  static const Map<String, List<String>> _dislikedKeywords = {
    // Proteínas animales
    'beef':           ['ternera', 'res', 'vacuno', 'carne magra', 'filete'],
    'pork':           ['cerdo', 'costilla'],
    'chicken':        ['pollo', 'pechuga'],
    'turkey':         ['pavo'],
    'lamb':           ['cordero'],
    'fish':           ['merluza', 'bacalao', 'lubina', 'pescado'],
    'salmon':         ['salmón', 'salmon'],
    'tuna':           ['atún', 'atun'],
    'seafood':        ['marisco', 'camarón', 'langostino', 'mejillón', 'calamar', 'pulpo'],
    'shrimp':         ['camarón', 'langostino'],
    'eggs':           ['huevo', 'huevos', 'claras', 'yema'],
    // Lácteos
    'milk':           ['leche', 'leche descremada', 'leche entera'],
    'cheese':         ['queso', 'feta', 'mozzarella', 'parmesano', 'manchego', 'ricotta', 'cottage'],
    'yogurt':         ['yogur', 'yogurt'],
    'butter':         ['mantequilla'],
    // Carbohidratos
    'bread':          ['pan', 'tostadas', 'rebanadas'],
    'rice':           ['arroz'],
    'pasta':          ['pasta', 'fideos', 'macarrones'],
    'potato':         ['patata', 'papa'],
    'sweet_potato':   ['batata', 'boniato', 'camote'],
    'oats':           ['avena'],
    'quinoa':         ['quinoa'],
    'corn':           ['maíz', 'maiz', 'choclo'],
    // Legumbres / semillas
    'beans':          ['frijoles', 'porotos', 'alubias'],
    'lentils':        ['lentejas'],
    'chickpeas':      ['garbanzos'],
    'peas':           ['guisantes', 'arvejas'],
    'tofu':           ['tofu', 'tempeh', 'edamame', 'soja'],
    'nuts':           ['nueces', 'almendras', 'anacardos', 'avellanas', 'pistachos', 'frutos secos'],
    'peanuts':        ['mantequilla de maní', 'mantequilla de mani', 'maní', 'mani', 'cacahuete'],
    // Vegetales
    'tomato':         ['tomate'],
    'onion':          ['cebolla'],
    'garlic':         ['ajo'],
    'lettuce':        ['lechuga'],
    'spinach':        ['espinaca'],
    'broccoli':       ['brócoli', 'brocoli'],
    'cauliflower':    ['coliflor'],
    'carrot':         ['zanahoria'],
    'pepper':         ['pimiento', 'morrón'],
    'cucumber':       ['pepino'],
    'mushrooms':      ['champiñones', 'champinones', 'hongos'],
    'eggplant':       ['berenjena'],
    'zucchini':       ['calabacín', 'calabacin', 'zapallito'],
    'olives':         ['aceitunas'],
    'avocado':        ['aguacate', 'palta'],
    // Frutas
    'apple':          ['manzana'],
    'banana':         ['plátano', 'platano', 'banana'],
    'orange':         ['naranja'],
    'strawberry':     ['fresa', 'frutilla', 'frutos rojos'],
    'grapes':         ['uvas'],
    'pineapple':      ['piña', 'pina', 'ananá'],
    'mango':          ['mango'],
    'papaya':         ['papaya'],
    'coconut':        ['coco', 'leche de coco'],
    // Otros
    'spicy':          ['picante', 'curry', 'pimentón'],
    'sugar':          ['azúcar', 'azucar', 'miel', 'sirope'],
    'soda':           ['refresco', 'bebida azucarada'],
    'coffee':         ['café', 'cafe'],
    'alcohol':        ['cerveza', 'vino', 'alcohol'],
    'processed_meat': ['chorizo', 'jamón', 'jamon', 'embutido'],
    'fast_food':      ['hamburguesa', 'pizza'],
    'fried_food':     ['frito', 'fritos'],
  };

  static List<Map<String, dynamic>> _filterAllergies(
    List<Map<String, dynamic>> items,
    List<String> allergies,
  ) {
    if (allergies.isEmpty) return items;
    final activeAllergies = allergies
        .where((a) => _allergenKeywords.containsKey(a.toLowerCase()))
        .map((a) => a.toLowerCase())
        .toList();
    if (activeAllergies.isEmpty) return items;

    return items.map((item) {
      final ingredients = (item['ingredients'] as List?)?.cast<String>() ?? [];
      final ingLower = ingredients.map((i) => i.toLowerCase()).toList();

      final matchedAllergens = <String>[];
      for (final allergen in activeAllergies) {
        final keywords = _allergenKeywords[allergen] ?? [allergen];
        final hasMatch = ingLower.any((ing) => keywords.any((kw) => ing.contains(kw)));
        if (hasMatch) matchedAllergens.add(allergen);
      }

      if (matchedAllergens.isEmpty) return item;

      final allergenNames = matchedAllergens.map((a) => a.replaceAll('_', ' ')).join(', ');
      return {
        ...item,
        'name': '⚠️ ${item['name']}',
        'ingredients': [...ingredients, '⚠️ Contiene: $allergenNames — consulta una alternativa con tu nutricionista'],
      };
    }).toList();
  }

  /// Marca los ítems que contienen alimentos no deseados por el usuario.
  /// A diferencia de las alergias (riesgo de salud), aquí sólo añadimos una
  /// nota sugerente: el usuario puede sustituir el ingrediente manualmente.
  /// No modifica calorías ni macros — sólo orienta visualmente.
  static List<Map<String, dynamic>> _filterDislikedFoods(
    List<Map<String, dynamic>> items,
    List<String> dislikedFoods,
  ) {
    if (dislikedFoods.isEmpty) return items;
    final active = dislikedFoods
        .where((d) => _dislikedKeywords.containsKey(d.toLowerCase()))
        .map((d) => d.toLowerCase())
        .toList();
    if (active.isEmpty) return items;

    return items.map((item) {
      final ingredients = (item['ingredients'] as List?)?.cast<String>() ?? [];
      final name = (item['name'] as String).toLowerCase();
      final ingLower = ingredients.map((i) => i.toLowerCase()).toList();

      final matched = <String>[];
      for (final disliked in active) {
        final keywords = _dislikedKeywords[disliked] ?? [disliked];
        final hit = ingLower.any((ing) => keywords.any((kw) => ing.contains(kw)))
            || keywords.any((kw) => name.contains(kw));
        if (hit) matched.add(disliked);
      }

      if (matched.isEmpty) return item;

      final names = matched.map((m) => m.replaceAll('_', ' ')).join(', ');
      return {
        ...item,
        'ingredients': [
          ...ingredients,
          '💡 Incluye: $names — siéntete libre de sustituirlo',
        ],
      };
    }).toList();
  }

  /// Normaliza las alergias del usuario a las claves conocidas del catálogo
  /// (descarta prefs dietarias y valores como 'ninguna'/'otro').
  static List<String> _normalizeAllergies(List<String> allergies) => allergies
      .map((a) => a.toLowerCase())
      .where(_allergenKeywords.containsKey)
      .toList();

  /// True si [text] (nombre + ingredientes) contiene algún alérgeno del usuario.
  /// Usado por la rama de IA (DB) para EXCLUIR recetas del pool, no solo advertir.
  static bool textHasAllergen(String text, List<String> allergies) {
    final active = _normalizeAllergies(allergies);
    if (active.isEmpty) return false;
    final lower = text.toLowerCase();
    for (final allergen in active) {
      final keywords = _allergenKeywords[allergen] ?? [allergen];
      if (keywords.any((kw) => lower.contains(kw))) return true;
    }
    return false;
  }

  /// Aplica solo la nota de "alimentos no deseados" (los disgustos no son riesgo
  /// de salud). Reutilizable desde la rama de IA (DB).
  static List<Map<String, dynamic>> annotateDislikes(
    List<Map<String, dynamic>> items,
    List<String> dislikedFoods,
  ) {
    final cleaned = dislikedFoods
        .where((d) => d.isNotEmpty && !d.startsWith('custom:'))
        .toList();
    if (cleaned.isEmpty) return items;
    return _filterDislikedFoods(items, cleaned);
  }

  static List<Map<String, dynamic>> _meals5(String pref, {required bool isLose, required bool isGain, required int seed, int dayIndex = 0, String? cookingTime}) {
    final base = _meals4(pref, isLose: isLose, isGain: isGain, seed: seed, dayIndex: dayIndex, cookingTime: cookingTime);
    final preWorkout = {
      'meal_type': 'snack',
      'name': 'Pre-entreno: banana con mantequilla de maní',
      'ingredients': ['1 plátano', '1 cda mantequilla de maní natural'],
      'calories': 190,
      'protein': 5.0,
      'carbs': 30.0,
      'fats': 7.0,
    };
    return [...base, preWorkout];
  }
}
