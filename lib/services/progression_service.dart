import 'package:supabase_flutter/supabase_flutter.dart';

/// Overlay deterministico sobre el plan IA: sets/reps reales y nudges
/// textuales (jamas sugerimos kg). Llama a la RPC server-side
/// recompute_progression_state que aplica las 7 reglas (regression por
/// abandono, falla repetida, deload, double-progression, +1 set, sin
/// cambio) y devuelve el estado actualizado por ejercicio.
class ProgressionService {
  ProgressionService._();
  static final ProgressionService instance = ProgressionService._();

  /// Recalcula y devuelve el overlay para los ejercicios dados.
  /// [baseSets]/[baseRepsMin]/[baseRepsMax] son el baseline POR EJERCICIO del
  /// plan de IA (alineados por índice con [exerciseNames]); se usan para
  /// sembrar el estado inicial diferenciado (compuesto 4x6-8, aislamiento
  /// 3x12-15) en vez de un 3x8-12 uniforme. Usa 0 cuando no se conoce.
  /// Si la RPC falla, devuelve un mapa vacio para fallback al plan IA.
  Future<Map<String, ExerciseProgression>> recompute(
    List<String> exerciseNames, {
    List<int>? baseSets,
    List<int>? baseRepsMin,
    List<int>? baseRepsMax,
  }) async {
    if (exerciseNames.isEmpty) return const {};
    try {
      final res = await Supabase.instance.client.rpc(
        'recompute_progression_state',
        params: {
          'p_exercise_names': exerciseNames,
          if (baseSets != null) 'p_base_sets': baseSets,
          if (baseRepsMin != null) 'p_base_reps_min': baseRepsMin,
          if (baseRepsMax != null) 'p_base_reps_max': baseRepsMax,
        },
      );
      if (res is! List) return const {};
      final out = <String, ExerciseProgression>{};
      for (final row in res) {
        if (row is! Map) continue;
        final name = row['exercise_name'] as String?;
        if (name == null) continue;
        out[name] = ExerciseProgression(
          exerciseName: name,
          sets: (row['current_sets'] as num?)?.toInt() ?? 3,
          repsMin: (row['reps_min'] as num?)?.toInt() ?? 8,
          repsMax: (row['reps_max'] as num?)?.toInt() ?? 12,
          nudgeType: row['nudge_type'] as String?,
          nudgeMessage: row['nudge_message'] as String?,
        );
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}

class ExerciseProgression {
  final String exerciseName;
  final int sets;
  final int repsMin;
  final int repsMax;
  final String? nudgeType;
  final String? nudgeMessage;

  const ExerciseProgression({
    required this.exerciseName,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    this.nudgeType,
    this.nudgeMessage,
  });

  String get repsLabel => '$repsMin-$repsMax';
  bool get hasNudge => nudgeType != null && nudgeMessage != null;
}
