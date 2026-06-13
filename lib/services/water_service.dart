import 'package:supabase_flutter/supabase_flutter.dart';
import 'badge_service.dart';

class WaterService {
  static final WaterService instance = WaterService._();
  WaterService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Vasos de hoy
  Future<int> getGlassesToday() async {
    final uid = _uid;
    if (uid == null) return 0;
    final row = await _client
        .from('water_logs')
        .select('glasses_count')
        .eq('user_id', uid)
        .eq('target_date', _today())
        .maybeSingle();
    return row?['glasses_count'] as int? ?? 0;
  }

  // Actualiza (o inserta) el registro de agua de hoy
  Future<void> setGlassesToday(int count) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('water_logs').upsert({
      'user_id': uid,
      'target_date': _today(),
      'glasses_count': count,
    }, onConflict: 'user_id, target_date');
  }

  // Suma un vaso al registro de hoy
  Future<int> addGlass() async {
    final current = await getGlassesToday();
    final next = current + 1;
    await setGlassesToday(next);
    final uid = _uid;
    if (uid != null) {
      await BadgeService.instance.checkAndAwardBadges(uid, 'water_logged');
    }
    return next;
  }

  // Fija el contador exacto (subir o bajar). Otorga medalla solo al subir.
  Future<void> setGlasses(int count) async {
    final next = count < 0 ? 0 : count;
    final current = await getGlassesToday();
    await setGlassesToday(next);
    if (next > current) {
      final uid = _uid;
      if (uid != null) {
        await BadgeService.instance.checkAndAwardBadges(uid, 'water_logged');
      }
    }
  }

  // Resetea el contador de hoy a cero
  Future<void> resetToday() async {
    await setGlassesToday(0);
  }
}
