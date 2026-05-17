import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_service.dart';

class WeightService {
  static final WeightService instance = WeightService._();
  WeightService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> getLogs({int limit = 30}) async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('weight_logs')
        .select('id, weight_kg, logged_at')
        .eq('user_id', uid)
        .order('logged_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> logWeight(double kg) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('weight_logs').insert({
      'user_id': uid,
      'weight_kg': kg,
    });
    await BadgeService.instance.checkAndAwardBadges(uid, 'weight_logged');
  }

  Future<void> deleteLog(String id) async {
    await _client.from('weight_logs').delete().eq('id', id);
  }
}
