import 'package:supabase_flutter/supabase_flutter.dart';

/// Objetivos nutricionales del usuario (un registro por usuario).
/// Persistido en `nutrition_goals` (ver migracion 20260518000002).
class NutritionGoalsService {
  static final NutritionGoalsService instance = NutritionGoalsService._();
  NutritionGoalsService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> get() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('nutrition_goals')
          .select(
            'id, daily_kcal, protein_g, carbs_g, fat_g, meals_per_day, recalc_at, updated_at',
          )
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required int kcal,
    required int protein,
    required int carbs,
    required int fat,
    int mealsPerDay = 4,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('nutrition_goals').upsert({
      'user_id': uid,
      'daily_kcal': kcal,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'meals_per_day': mealsPerDay,
      'recalc_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// True si los objetivos deben recalcularse: o bien no existen, o bien hay
  /// un cambio de peso/objetivo posterior a `recalc_at`.
  Future<bool> needsRecalc() async {
    final uid = _uid;
    if (uid == null) return false;
    final goals = await get();
    if (goals == null) return true;
    final recalcAt = goals['recalc_at'] as String?;
    if (recalcAt == null) return true;

    try {
      final weights = await _client
          .from('weight_logs')
          .select('logged_at')
          .eq('user_id', uid)
          .gt('logged_at', recalcAt)
          .limit(1);
      if ((weights as List).isNotEmpty) return true;
    } catch (_) {}

    try {
      final goalChanges = await _client
          .from('profile_change_logs')
          .select('id')
          .eq('user_id', uid)
          .eq('field', 'fitness_goal')
          .gt('changed_at', recalcAt)
          .limit(1);
      if ((goalChanges as List).isNotEmpty) return true;
    } catch (_) {}

    return false;
  }
}
