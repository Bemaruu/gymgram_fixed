import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionTier { free, plus, premium }

enum SubscriptionVariant { normal, launch, founder }

/// Estado completo de suscripcion del usuario actual.
class SubscriptionStatus {
  final SubscriptionTier tier;
  final SubscriptionVariant variant;
  final SubscriptionTier? pendingTier;
  final DateTime? periodEnd;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.tier,
    required this.variant,
    required this.pendingTier,
    required this.periodEnd,
    required this.expiresAt,
  });

  bool get isPaid => tier != SubscriptionTier.free;
  bool get hasPendingChange => pendingTier != null;
}

/// Lee y actualiza el tier de suscripcion. La escritura de campos sensibles
/// esta protegida por el trigger `prevent_subscription_field_changes`
/// (ver migracion 20260520000005_subscription_pending_tier.sql):
///
/// - subscription_tier / subscription_variant / subscription_expires_at /
///   subscription_period_end: solo service_role.
/// - pending_tier: el cliente puede setearlo solo para downgrade (premium->plus)
///   o cancelacion (paid->free), o ponerlo en null para revertir.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  final _client = Supabase.instance.client;

  SubscriptionStatus? _cached;
  DateTime? _cachedAt;
  static const _ttl = Duration(minutes: 5);

  Future<SubscriptionTier> currentTier({bool forceRefresh = false}) async {
    final status = await currentStatus(forceRefresh: forceRefresh);
    return status.tier;
  }

  Future<SubscriptionStatus> currentStatus({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < _ttl) {
      return _cached!;
    }

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const SubscriptionStatus(
        tier: SubscriptionTier.free,
        variant: SubscriptionVariant.normal,
        pendingTier: null,
        periodEnd: null,
        expiresAt: null,
      );
    }

    // Intento 1: query extendida con columnas nuevas (pending_tier,
    // subscription_period_end). Si la migracion 20260520000005 todavia no se
    // aplica esas columnas no existen y la query falla; en ese caso caemos al
    // intento 2 con las columnas que sabemos que existen desde antes.
    try {
      final row = await _client
          .from('profiles')
          .select(
            'subscription_tier, subscription_variant, pending_tier, subscription_period_end, subscription_expires_at',
          )
          .eq('id', uid)
          .maybeSingle();

      final status = SubscriptionStatus(
        tier: _parseTier(row?['subscription_tier'] as String?),
        variant: _parseVariant(row?['subscription_variant'] as String?),
        pendingTier: _parseTierNullable(row?['pending_tier'] as String?),
        periodEnd: _parseDate(row?['subscription_period_end']),
        expiresAt: _parseDate(row?['subscription_expires_at']),
      );
      _cached = status;
      _cachedAt = now;
      return status;
    } catch (_) {
      // Fallback: columnas nuevas aun no existen.
    }

    try {
      final row = await _client
          .from('profiles')
          .select(
            'subscription_tier, subscription_variant, subscription_expires_at',
          )
          .eq('id', uid)
          .maybeSingle();

      final status = SubscriptionStatus(
        tier: _parseTier(row?['subscription_tier'] as String?),
        variant: _parseVariant(row?['subscription_variant'] as String?),
        pendingTier: null,
        periodEnd: null,
        expiresAt: _parseDate(row?['subscription_expires_at']),
      );
      _cached = status;
      _cachedAt = now;
      return status;
    } catch (_) {
      return const SubscriptionStatus(
        tier: SubscriptionTier.free,
        variant: SubscriptionVariant.normal,
        pendingTier: null,
        periodEnd: null,
        expiresAt: null,
      );
    }
  }

  bool isPremium(SubscriptionTier t) => t != SubscriptionTier.free;

  void invalidate() {
    _cached = null;
    _cachedAt = null;
  }

  /// Agenda un downgrade a Plus al final del periodo actual.
  /// Solo aplica si el usuario actual es Premium.
  Future<void> scheduleDowngradeToPlus() async {
    await _setPendingTier('plus');
  }

  /// Agenda la cancelacion (paso a Free) al final del periodo actual.
  /// Aplica si el usuario es Plus o Premium.
  Future<void> scheduleCancellation() async {
    await _setPendingTier('free');
  }

  /// Revierte un cambio agendado (mantiene el plan actual indefinidamente).
  Future<void> revertPendingChange() async {
    await _setPendingTier(null);
  }

  Future<void> _setPendingTier(String? value) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Usuario no autenticado');
    }
    await _client
        .from('profiles')
        .update({'pending_tier': value}).eq('id', uid);
    invalidate();
  }

  SubscriptionTier _parseTier(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'plus':
        return SubscriptionTier.plus;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  SubscriptionTier? _parseTierNullable(String? raw) {
    if (raw == null) return null;
    return _parseTier(raw);
  }

  SubscriptionVariant _parseVariant(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'launch':
        return SubscriptionVariant.launch;
      case 'founder':
        return SubscriptionVariant.founder;
      default:
        return SubscriptionVariant.normal;
    }
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}
