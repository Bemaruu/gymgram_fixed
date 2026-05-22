import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Check-in semanal del usuario (Plus + Premium).
/// week_start es el lunes de la semana actual (date-only).
class WeeklyCheckinService {
  static final WeeklyCheckinService instance = WeeklyCheckinService._();
  WeeklyCheckinService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Calcula el lunes (00:00 local) de la semana de [d]. Retorna date-only ISO.
  String _weekStartIsoDate(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final m = DateTime(monday.year, monday.month, monday.day);
    return '${m.year.toString().padLeft(4, '0')}-'
        '${m.month.toString().padLeft(2, '0')}-'
        '${m.day.toString().padLeft(2, '0')}';
  }

  Future<bool> submitCheckin(String response) async {
    final uid = _uid;
    if (uid == null) return false;
    String? id;
    try {
      final row = await _client
          .from('ai_weekly_checkins')
          .insert({
            'user_id': uid,
            'week_start': _weekStartIsoDate(DateTime.now()),
            'response': response,
          })
          .select('id')
          .single();
      id = row['id'] as String?;
    } catch (e) {
      debugPrint('WeeklyCheckinService.submitCheckin error: $e');
      return false;
    }
    if (id != null) {
      unawaited(_triggerAiResponse(id));
    }
    return true;
  }

  Future<void> _triggerAiResponse(String checkinId) async {
    try {
      await _client.functions.invoke(
        'weekly-checkin-response',
        body: {'checkin_id': checkinId},
      );
    } catch (e) {
      debugPrint('weekly-checkin-response invoke error: $e');
    }
  }

  Future<bool> hasCheckedInThisWeek() async {
    final uid = _uid;
    if (uid == null) return false;
    final ws = _weekStartIsoDate(DateTime.now());
    try {
      final row = await _client
          .from('ai_weekly_checkins')
          .select('id')
          .eq('user_id', uid)
          .eq('week_start', ws)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCheckinHistory({int months = 1}) async {
    final uid = _uid;
    if (uid == null) return [];
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - months, now.day);
    final sinceDate = _weekStartIsoDate(since);
    try {
      final rows = await _client
          .from('ai_weekly_checkins')
          .select('id, week_start, response, created_at')
          .eq('user_id', uid)
          .gte('week_start', sinceDate)
          .order('week_start', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('WeeklyCheckinService.getCheckinHistory error: $e');
      return [];
    }
  }
}
