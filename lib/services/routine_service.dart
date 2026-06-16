import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_service.dart';
import 'subscription_service.dart';

class RoutineService {
  static final RoutineService instance = RoutineService._();
  RoutineService._();

  static const int freeCommunityLimit = 5;

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Cuantas rutinas comunitarias activas tiene el usuario. Free maximo 5.
  Future<int> myCommunityRoutinesCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final rows = await _client
          .from('routines')
          .select('id')
          .eq('user_id', uid)
          .eq('kind', 'community')
          .neq('is_archived', true);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Si el usuario puede publicar mas rutinas comunitarias.
  /// Free: max 5. Plus/Premium: ilimitado.
  Future<bool> canPublishCommunityRoutine() async {
    final tier = await SubscriptionService.instance.currentTier();
    if (tier != SubscriptionTier.free) return true;
    final count = await myCommunityRoutinesCount();
    return count < freeCommunityLimit;
  }

  // Devuelve todas las rutinas del usuario (con sus ejercicios)
  // (kind='personal' por compatibilidad con RoutineScreen)
  Future<List<Map<String, dynamic>>> getMyRoutines() => getMyPersonalRoutines();

  /// Pide a la edge `analyze-routine` una opinión IA sobre la rutina
  /// importada por el usuario. Devuelve el análisis estructurado o null
  /// si falla. El backend ya persiste el resultado en `routines.routine_analysis`.
  Future<Map<String, dynamic>?> requestRoutineAnalysis() async {
    try {
      final res = await _client.functions.invoke('analyze-routine');
      if (res.status != 200) return null;
      final data = res.data;
      if (data is! Map) return null;
      final analysis = data['analysis'];
      return analysis is Map ? Map<String, dynamic>.from(analysis) : null;
    } catch (_) {
      return null;
    }
  }

  /// Marca el análisis IA de una rutina como dismissed por el usuario.
  /// El banner deja de aparecer hasta que se pida un nuevo análisis (que
  /// sobrescribe `routine_analysis`).
  Future<bool> dismissRoutineAnalysis(String routineId) async {
    try {
      final current = await _client
          .from('routines')
          .select('routine_analysis')
          .eq('id', routineId)
          .maybeSingle();
      final analysis = current?['routine_analysis'];
      final next = <String, dynamic>{
        if (analysis is Map) ...Map<String, dynamic>.from(analysis),
        'dismissed': true,
      };
      await _client
          .from('routines')
          .update({'routine_analysis': next})
          .eq('id', routineId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Rutina personal (semanal) propia: una entrada por dia
  Future<List<Map<String, dynamic>>> getMyPersonalRoutines() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('user_id', uid)
        .eq('kind', 'personal')
        .eq('is_archived', false)
        .order('day_of_week');
    return List<Map<String, dynamic>>.from(result);
  }

  // Rutinas comunitarias propias (las que el user creo para compartir)
  Future<List<Map<String, dynamic>>> getMyCommunityRoutines() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('user_id', uid)
        .eq('kind', 'community')
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  // Rutina personal de otro usuario (semanal, publica)
  Future<List<Map<String, dynamic>>> getPersonalRoutinesByUserId(
      String userId) async {
    final result = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('user_id', userId)
        .eq('kind', 'personal')
        .eq('is_public', true)
        .eq('is_archived', false)
        .order('day_of_week');
    return List<Map<String, dynamic>>.from(result);
  }

  // Rutinas comunitarias de otro usuario (publicas)
  Future<List<Map<String, dynamic>>> getCommunityRoutinesByUserId(
      String userId) async {
    final result = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('user_id', userId)
        .eq('kind', 'community')
        .eq('is_public', true)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  // True si hay una rutina archivada para ese dia (para mostrar boton restaurar)
  Future<bool> hasArchivedRoutineForDay(int dayOfWeek) async {
    final uid = _uid;
    if (uid == null) return false;
    final result = await _client
        .from('routines')
        .select('id')
        .eq('user_id', uid)
        .eq('kind', 'personal')
        .eq('day_of_week', dayOfWeek)
        .eq('is_archived', true)
        .limit(1)
        .maybeSingle();
    return result != null;
  }

  // Restaura la rutina archivada mas reciente del dia y elimina la activa actual.
  Future<void> restorePersonalDay(int dayOfWeek) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');

    // Buscar la archivada mas reciente
    final archived = await _client
        .from('routines')
        .select('id')
        .eq('user_id', uid)
        .eq('kind', 'personal')
        .eq('day_of_week', dayOfWeek)
        .eq('is_archived', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (archived == null) return;

    // Borrar la activa actual del dia (si existe)
    await _client
        .from('routines')
        .delete()
        .eq('user_id', uid)
        .eq('kind', 'personal')
        .eq('day_of_week', dayOfWeek)
        .eq('is_archived', false);

    // Desarchivar la archivada
    await _client
        .from('routines')
        .update({'is_archived': false})
        .eq('id', archived['id']);
  }

  // [DEPRECATED] mantener por compatibilidad: devuelve community publicas
  Future<List<Map<String, dynamic>>> getRoutinesByUserId(String userId) async {
    return getCommunityRoutinesByUserId(userId);
  }

  // Crea una rutina comunitaria (sin day_of_week, kind='community')
  Future<String> saveCommunityRoutine({
    required String title,
    required String goal,
    required String trainingLocation,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');

    final routine = await _client.from('routines').insert({
      'user_id': uid,
      'title': title,
      'goal': goal,
      'training_location': trainingLocation,
      'kind': 'community',
      'is_public': true,
    }).select().single();

    final routineId = routine['id'] as String;

    if (exercises.isNotEmpty) {
      final rows = exercises.asMap().entries.map((e) => {
            'routine_id': routineId,
            'name': e.value['name'],
            'sets': e.value['sets'],
            'reps': e.value['reps'],
            'rest_seconds': e.value['rest_seconds'],
            'muscle_group': e.value['muscle_group'],
            'order_index': e.key,
          }).toList();
      await _client.from('routine_exercises').insert(rows);
    }

    return routineId;
  }

  // Copia las 7 rutinas (semana personal) de otro usuario al perfil propio.
  // Reemplaza las rutinas personales propias del mismo dia si existen.
  // Devuelve cantidad de dias copiados.
  Future<int> copyPersonalWeek(String sourceUserId) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');
    if (uid == sourceUserId) return 0;

    final source = await getPersonalRoutinesByUserId(sourceUserId);
    if (source.isEmpty) return 0;

    int copied = 0;
    for (final r in source) {
      final sourceId = r['id'] as String;

      // Registrar copia (idempotente)
      try {
        await _client.from('routine_copies').insert({
          'routine_id': sourceId,
          'user_id': uid,
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }

      // Archivar mi rutina personal del mismo dia (si existe) en vez de borrarla,
      // para permitir restaurar despues. Tambien la marcamos no publica.
      final dayIndex = r['day_of_week'] as int?;
      if (dayIndex != null) {
        await _client
            .from('routines')
            .update({'is_archived': true, 'is_public': false})
            .eq('user_id', uid)
            .eq('kind', 'personal')
            .eq('day_of_week', dayIndex)
            .eq('is_archived', false);
      }

      // Clonar
      final cloned = await _client.from('routines').insert({
        'user_id': uid,
        'title': r['title'],
        'goal': r['goal'],
        'training_location': r['training_location'],
        'day_of_week': dayIndex,
        'kind': 'personal',
        'is_public': false,
        'source_routine_id': sourceId,
      }).select().single();

      final newId = cloned['id'] as String;
      final exercises =
          (r['routine_exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (exercises.isNotEmpty) {
        final rows = exercises.asMap().entries.map((e) => {
              'routine_id': newId,
              'name': e.value['name'],
              'sets': e.value['sets'],
              'reps': e.value['reps'],
              'rest_seconds': e.value['rest_seconds'],
              'muscle_group': e.value['muscle_group'],
              'order_index': e.key,
            }).toList();
        await _client.from('routine_exercises').insert(rows);
      }
      copied++;
    }
    return copied;
  }

  // Copia una rutina de otro usuario al perfil propio.
  // Devuelve el id de la rutina nueva (clon) o null si ya estaba copiada.
  Future<String?> copyRoutine(String sourceRoutineId, {int? dayOfWeek}) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');

    // 1) Verificar si ya existe una copia visible (evita bloqueo por registros rotos)
    final existingCopy = await _client
        .from('routines')
        .select('id')
        .eq('user_id', uid)
        .eq('source_routine_id', sourceRoutineId)
        .eq('kind', 'personal')
        .eq('is_archived', false)
        .maybeSingle();
    if (existingCopy != null) return null;

    // 2) Cargar rutina origen + ejercicios
    final src = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('id', sourceRoutineId)
        .maybeSingle();
    if (src == null) throw Exception('Rutina no encontrada');

    // 3) Registrar la copia (idempotente, ignora duplicados)
    await _client.from('routine_copies').upsert(
      {'routine_id': sourceRoutineId, 'user_id': uid},
      onConflict: 'routine_id,user_id',
      ignoreDuplicates: true,
    );

    // 4) Archivar la rutina personal activa del dia destino (si existe) para
    //    respetar "un dia = una rutina" (indice unico) y permitir restaurarla.
    final effectiveDay = dayOfWeek ?? src['day_of_week'] as int?;
    if (effectiveDay != null) {
      await _client
          .from('routines')
          .update({'is_archived': true, 'is_public': false})
          .eq('user_id', uid)
          .eq('kind', 'personal')
          .eq('day_of_week', effectiveDay)
          .eq('is_archived', false);
    }

    // 5) Clonar la rutina al usuario actual
    final newRoutine = await _client.from('routines').insert({
      'user_id': uid,
      'title': src['title'],
      'goal': src['goal'],
      'training_location': src['training_location'],
      'day_of_week': effectiveDay,
      'kind': 'personal',
      'source_routine_id': sourceRoutineId,
      'is_public': false,
    }).select().single();

    final newRoutineId = newRoutine['id'] as String;

    // 6) Clonar ejercicios
    final exercises =
        (src['routine_exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (exercises.isNotEmpty) {
      final rows = exercises.asMap().entries.map((e) => {
            'routine_id': newRoutineId,
            'name': e.value['name'],
            'sets': e.value['sets'],
            'reps': e.value['reps'],
            'rest_seconds': e.value['rest_seconds'],
            'muscle_group': e.value['muscle_group'],
            'order_index': e.key,
          }).toList();
      await _client.from('routine_exercises').insert(rows);
    }

    return newRoutineId;
  }

  // True si el usuario actual ya copio esa rutina y existe una copia visible
  Future<bool> hasCopiedRoutine(String sourceRoutineId) async {
    final uid = _uid;
    if (uid == null) return false;
    final result = await _client
        .from('routines')
        .select('id')
        .eq('user_id', uid)
        .eq('source_routine_id', sourceRoutineId)
        .eq('kind', 'personal')
        .eq('is_archived', false)
        .maybeSingle();
    return result != null;
  }

  /// Archiva las rutinas personales de días que NO son de entrenamiento.
  /// Corrige datos históricos donde el fallback de 7 días creó rutinas de más.
  /// Las rutinas archivadas no aparecen en el perfil propio ni en el ajeno.
  Future<void> archiveNonTrainingDays(List<int> trainingDayIndices) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Primero desarchivamos los días activos para que vuelvan a ser visibles
      // si el usuario re-activó un día antes deshabilitado.
      if (trainingDayIndices.isNotEmpty) {
        await _client
            .from('routines')
            .update({'is_archived': false, 'is_public': true})
            .eq('user_id', uid)
            .eq('kind', 'personal')
            .inFilter('day_of_week', trainingDayIndices);
      }
      // Archivamos los días que no son de entrenamiento
      final restDays = List.generate(7, (i) => i)
          .where((i) => !trainingDayIndices.contains(i))
          .toList();
      if (restDays.isNotEmpty) {
        await _client
            .from('routines')
            .update({'is_archived': true, 'is_public': false})
            .eq('user_id', uid)
            .eq('kind', 'personal')
            .eq('is_archived', false)
            .inFilter('day_of_week', restDays);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('archiveNonTrainingDays error: $e');
    }
  }

  // Devuelve los ejercicios de una rutina específica
  Future<List<Map<String, dynamic>>> getExercises(String routineId) async {
    final result = await _client
        .from('routine_exercises')
        .select()
        .eq('routine_id', routineId)
        .order('order_index');
    return List<Map<String, dynamic>>.from(result);
  }

  // Guarda una rutina completa con sus ejercicios
  Future<String> saveRoutine({
    required String title,
    required String goal,
    required String trainingLocation,
    required int dayOfWeek,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');

    // Reutiliza la rutina personal activa del dia si ya existe, para no crear
    // duplicados (un dia = una rutina). Garantizado tambien por indice unico en DB.
    final existing = await _client
        .from('routines')
        .select('id')
        .eq('user_id', uid)
        .eq('kind', 'personal')
        .eq('is_archived', false)
        .eq('day_of_week', dayOfWeek)
        .maybeSingle();

    final String routineId;
    if (existing != null) {
      routineId = existing['id'] as String;
      await _client.from('routines').update({
        'title': title,
        'goal': goal,
        'training_location': trainingLocation,
      }).eq('id', routineId);
      // Reemplaza los ejercicios del dia
      await _client.from('routine_exercises').delete().eq('routine_id', routineId);
    } else {
      final routine = await _client.from('routines').insert({
        'user_id': uid,
        'title': title,
        'goal': goal,
        'training_location': trainingLocation,
        'day_of_week': dayOfWeek,
        'kind': 'personal',
        'is_public': true,
      }).select().single();
      routineId = routine['id'] as String;
    }

    // Inserta los ejercicios
    if (exercises.isNotEmpty) {
      final exerciseRows = exercises.asMap().entries.map((e) => {
        'routine_id': routineId,
        'name': e.value['name'],
        'sets': e.value['sets'],
        'reps': e.value['reps'],
        'rest_seconds': e.value['rest_seconds'],
        'muscle_group': e.value['muscle_group'],
        'order_index': e.key,
      }).toList();

      await _client.from('routine_exercises').insert(exerciseRows);
    }

    await BadgeService.instance.checkAndAwardBadges(uid, 'workout_completed');
    return routineId;
  }

  // Reemplaza los ejercicios de una rutina existente
  Future<void> updateExercises(String routineId, List<Map<String, dynamic>> exercises) async {
    await _client.from('routine_exercises').delete().eq('routine_id', routineId);
    if (exercises.isNotEmpty) {
      final rows = exercises.asMap().entries.map((e) => {
        'routine_id': routineId,
        'name': e.value['name'],
        'sets': e.value['sets'],
        'reps': e.value['reps'],
        'rest_seconds': e.value['rest_seconds'],
        'muscle_group': e.value['muscle_group'],
        'order_index': e.key,
      }).toList();
      await _client.from('routine_exercises').insert(rows);
    }
  }

  Future<void> deleteRoutine(String routineId) async {
    await _client.from('routines').delete().eq('id', routineId);
  }

  Future<String?> logWorkoutExecution({String? routineId}) async {
    final uid = _uid;
    if (uid == null) return null;
    String? workoutLogId;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      // limit(1) evita que maybeSingle() lance si existen filas duplicadas
      // para el mismo dia (datos heredados de la condicion de carrera previa).
      final existing = await _client
          .from('workout_logs')
          .select('id')
          .eq('user_id', uid)
          .eq('logged_at', today)
          .order('logged_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (existing == null) {
        try {
          final inserted = await _client.from('workout_logs').insert({
            'user_id': uid,
            'routine_id': routineId,
            'logged_at': today,
          }).select('id').single();
          workoutLogId = inserted['id'] as String?;
        } catch (_) {
          // Si el indice unico (user_id, logged_at) rechaza un insert
          // concurrente, re-leemos la fila que ya existe.
          final row = await _client
              .from('workout_logs')
              .select('id')
              .eq('user_id', uid)
              .eq('logged_at', today)
              .limit(1)
              .maybeSingle();
          workoutLogId = row?['id'] as String?;
        }
      } else {
        workoutLogId = existing['id'] as String?;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('logWorkoutExecution error: $e');
    }
    await BadgeService.instance.checkAndAwardBadges(uid, 'workout_completed');
    return workoutLogId;
  }
}
