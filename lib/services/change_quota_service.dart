import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';

/// Reglas de cuota anual para cambios de campos sensibles del perfil.
/// - Limite: 4 cambios/anio calendario para usuarios `free` en `fitness_goal`
///   y `training_location`.
/// - `plus` y `premium`: ilimitado.
class ChangeQuotaService {
  static final ChangeQuotaService instance = ChangeQuotaService._();
  ChangeQuotaService._();

  static const int yearlyLimit = 4;
  static const Set<String> trackedFields = {'fitness_goal', 'training_location'};

  final _client = Supabase.instance.client;

  Future<int> usedThisYear(String field) async {
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
          .eq('field', field)
          .gte('changed_at', yearStart.toIso8601String())
          .lt('changed_at', yearEnd.toIso8601String());
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> canChange(String field) async {
    final tier = await SubscriptionService.instance.currentTier();
    if (SubscriptionService.instance.isPremium(tier)) return true;
    final used = await usedThisYear(field);
    return used < yearlyLimit;
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

  Future<({int used, int limit, bool unlimited})> quotaFor(String field) async {
    final tier = await SubscriptionService.instance.currentTier();
    if (SubscriptionService.instance.isPremium(tier)) {
      return (used: 0, limit: yearlyLimit, unlimited: true);
    }
    final used = await usedThisYear(field);
    return (used: used, limit: yearlyLimit, unlimited: false);
  }
}
