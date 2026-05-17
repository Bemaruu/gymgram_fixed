import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionTier { free, plus, premium }

/// Lee el tier de suscripcion del usuario actual desde `profiles.subscription_tier`.
/// La escritura del tier esta protegida server-side por trigger (ver migracion
/// `20260514000003_subscription_tier.sql`).
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  final _client = Supabase.instance.client;

  SubscriptionTier? _cached;
  DateTime? _cachedAt;
  static const _ttl = Duration(minutes: 5);

  Future<SubscriptionTier> currentTier({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cached!;
    }

    final uid = _client.auth.currentUser?.id;
    if (uid == null) return SubscriptionTier.free;

    try {
      final row = await _client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', uid)
          .maybeSingle();
      final raw = (row?['subscription_tier'] as String?)?.toLowerCase();
      final tier = _parse(raw);
      _cached = tier;
      _cachedAt = now;
      return tier;
    } catch (_) {
      return SubscriptionTier.free;
    }
  }

  bool isPremium(SubscriptionTier t) => t != SubscriptionTier.free;

  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  SubscriptionTier _parse(String? raw) {
    switch (raw) {
      case 'plus':
        return SubscriptionTier.plus;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }
}
