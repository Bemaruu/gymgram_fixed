import 'package:supabase_flutter/supabase_flutter.dart';

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
    return next;
  }

  // Resetea el contador de hoy a cero
  Future<void> resetToday() async {
    await setGlassesToday(0);
  }
}
