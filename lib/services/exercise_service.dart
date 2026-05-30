import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/input_sanitizers.dart';

class ExerciseService {
  static final ExerciseService instance = ExerciseService._();
  ExerciseService._();

  final _client = Supabase.instance.client;

  static const muscleGroups = [
    'Todos',
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Cuádriceps',
    'Femoral',
    'Glúteos',
    'Pantorrillas',
    'Core',
    'Lumbar',
    'Cadena posterior',
    'Cardio',
    'Deportes',
  ];

  Future<Map<String, String?>> mediaUrlsByName(List<String> names) async {
    if (names.isEmpty) return {};
    final result = await _client
        .from('exercise_catalog')
        .select('name_es, media_url')
        .inFilter('name_es', names);
    return {
      for (final row in (result as List))
        row['name_es'] as String: row['media_url'] as String?
    };
  }

  Future<List<Map<String, dynamic>>> getExercises({
    String? muscleGroup,
    String? location,
    String? query,
  }) async {
    var q = _client
        .from('exercise_catalog')
        .select(
          'id, name_es, slug, muscle_group_primary, muscle_group_secondary, location, equipment, exercise_type, difficulty, media_url',
        )
        .eq('is_active', true);

    if (muscleGroup != null && muscleGroup != 'Todos') {
      q = q.eq('muscle_group_primary', muscleGroup);
    }
    if (location != null) {
      // Allowlist: location es un enum controlado en la DB; descartamos
      // cualquier valor inesperado para evitar inyección en el filtro.
      const allowedLocations = {'gym', 'home', 'both'};
      if (allowedLocations.contains(location)) {
        q = q.or('location.eq.$location,location.eq.both');
      }
    }
    if (query != null && query.isNotEmpty) {
      final safeQuery = InputSanitizers.safePostgrestLike(query);
      if (safeQuery.isNotEmpty) {
        q = q.ilike('name_es', '%$safeQuery%');
      }
    }

    final result = await q.order('name_es');
    return List<Map<String, dynamic>>.from(result);
  }
}
