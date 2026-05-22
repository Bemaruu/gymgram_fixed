import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';

/// Cuota anual COMBINADA de cambios sensibles del perfil.
/// Cuenta TODOS los campos en `trackedFields` juntos durante el ano calendario.
///
/// Limites por tier:
/// - free:    4 cambios/ano
/// - plus:    8 cambios/ano
/// - premium: 12 cambios/ano
class ChangeQuotaService {
  static final ChangeQuotaService instance = ChangeQuotaService._();
  ChangeQuotaService._();

  static const Set<String> trackedFields = {
    'fitness_goal',
    'training_location',
    'routine_ai_change',
  };

  /// Limite legacy (= free). Se mantiene por compat con UIs antiguas.
  /// Las UIs nuevas deben leer `quotaFor()`.limit.
  static const int yearlyLimit = 4;

  final _client = Supabase.instance.client;

  static int yearlyLimitFor(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return 4;
      case SubscriptionTier.plus:
        return 8;
      case SubscriptionTier.premium:
        return 12;
    }
  }

  /// Total combinado de cambios usados este ano (todos los campos juntos).
  Future<int> usedThisYear() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0;
    final now = DateTime.now();
    final yearStart = DateTime.utc(now.year, 1, 1);
    final yearEnd = DateTime.utc(now.year + 1, 1, 1);

    try {
      final rows = await _client
          .from('profile_change_logs')
          .select('id')
          .eq('user_id', uid)
          .inFilter('field', trackedFields.toList())
          .gte('changed_at', yearStart.toIso8601String())
          .lt('changed_at', yearEnd.toIso8601String());
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> canChange() async {
    final tier = await SubscriptionService.instance.currentTier();
    final limit = yearlyLimitFor(tier);
    final used = await usedThisYear();
    return used < limit;
  }

  Future<void> recordChange({
    required String field,
    String? oldValue,
    String? newValue,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    if (!trackedFields.contains(field)) return;
    await _client.from('profile_change_logs').insert({
      'user_id': uid,
      'field': field,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  Future<({int used, int limit})> quotaFor() async {
    final tier = await SubscriptionService.instance.currentTier();
    final limit = yearlyLimitFor(tier);
    final used = await usedThisYear();
    return (used: used, limit: limit);
  }
}
