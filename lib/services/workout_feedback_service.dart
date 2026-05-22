import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Feedback post-entreno (Premium). El usuario responde una pregunta breve
/// tras completar un workout. La edge function `post-workout-ai-response`
/// rellena `ai_response` mas tarde.
class WorkoutFeedbackService {
  static final WorkoutFeedbackService instance = WorkoutFeedbackService._();
  WorkoutFeedbackService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<String?> submitFeedback(String response) async {
    final uid = _uid;
    if (uid == null) return null;
    String? id;
    try {
      final row = await _client
          .from('workout_feedback')
          .insert({
            'user_id': uid,
            'user_response': response,
            'workout_completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();
      id = row['id'] as String?;
    } catch (e) {
      debugPrint('WorkoutFeedbackService.submitFeedback error: $e');
      return null;
    }
    if (id != null) {
      // Disparar la edge function en background (fire-and-forget).
      // La respuesta del coach llega via FCM/realtime; no bloqueamos UI.
      unawaited(_triggerAiResponse(id));
    }
    return id;
  }

  Future<void> _triggerAiResponse(String feedbackId) async {
    try {
      await _client.functions.invoke(
        'post-workout-ai-response',
        body: {'feedback_id': feedbackId},
      );
    } catch (e) {
      debugPrint('post-workout-ai-response invoke error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentFeedback({int months = 1}) async {
    final uid = _uid;
    if (uid == null) return [];
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: 31 * months));
    try {
      final rows = await _client
          .from('workout_feedback')
          .select('id, workout_completed_at, user_response, ai_response, ai_responded_at')
          .eq('user_id', uid)
          .gte('workout_completed_at', since.toIso8601String())
          .order('workout_completed_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('WorkoutFeedbackService.getRecentFeedback error: $e');
      return [];
    }
  }

  Future<bool> hasFeedbackToday() async {
    final uid = _uid;
    if (uid == null) return false;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    try {
      final rows = await _client
          .from('workout_feedback')
          .select('id')
          .eq('user_id', uid)
          .gte('workout_completed_at', start.toIso8601String())
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
