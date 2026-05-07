import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_service.dart';

class RoutineService {
  static final RoutineService instance = RoutineService._();
  RoutineService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // Devuelve todas las rutinas del usuario (con sus ejercicios)
  Future<List<Map<String, dynamic>>> getMyRoutines() async {
    final uid = _uid;
    if (uid == null) return [];
    final result = await _client
        .from('routines')
        .select('*, routine_exercises(*)')
        .eq('user_id', uid)
        .order('day_of_week');
    return List<Map<String, dynamic>>.from(result);
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

    // Inserta la rutina
    final routine = await _client.from('routines').insert({
      'user_id': uid,
      'title': title,
      'goal': goal,
      'training_location': trainingLocation,
      'day_of_week': dayOfWeek,
    }).select().single();

    final routineId = routine['id'] as String;

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

  Future<void> logWorkoutExecution({String? routineId}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final existing = await _client
          .from('workout_logs')
          .select('id')
          .eq('user_id', uid)
          .eq('logged_at', today)
          .maybeSingle();
      if (existing == null) {
        await _client.from('workout_logs').insert({
          'user_id': uid,
          'routine_id': routineId,
          'logged_at': today,
        });
      }
    } catch (e) {
      debugPrint('logWorkoutExecution error: $e');
    }
    await BadgeService.instance.checkAndAwardBadges(uid, 'workout_completed');
  }
}
