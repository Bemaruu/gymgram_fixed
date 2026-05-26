import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sistema de referidos. Cada perfil tiene un `referral_code` único; un usuario
/// nuevo puede canjear el código de otro vía la RPC `redeem_referral`.
class ReferralService {
  static final ReferralService instance = ReferralService._();
  ReferralService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Código de referido del usuario actual (lo genera la DB al crear el perfil).
  Future<String?> getMyCode() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('referral_code')
          .eq('id', uid)
          .maybeSingle();
      return row?['referral_code'] as String?;
    } catch (e) {
      debugPrint('ReferralService.getMyCode error: $e');
      return null;
    }
  }

  /// Cantidad de usuarios que han canjeado mi código.
  Future<int> getReferralCount() async {
    if (_uid == null) return 0;
    try {
      final res = await _client.rpc('my_referral_count');
      if (res is int) return res;
      return int.tryParse('$res') ?? 0;
    } catch (e) {
      debugPrint('ReferralService.getReferralCount error: $e');
      return 0;
    }
  }

  /// Si el usuario ya canjeó un código (tiene referente).
  Future<bool> hasRedeemed() async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('referred_by')
          .eq('id', uid)
          .maybeSingle();
      return row?['referred_by'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Canjea un código. Devuelve null si OK, o un mensaje de error legible.
  Future<String?> redeem(String code) async {
    if (_uid == null) return 'Debes iniciar sesión.';
    final clean = code.trim();
    if (clean.isEmpty) return 'Ingresa un código.';
    try {
      final res = await _client.rpc('redeem_referral', params: {'p_code': clean});
      final map = res is Map ? res : <String, dynamic>{};
      if (map['ok'] == true) return null;
      switch (map['reason']) {
        case 'already_redeemed':
          return 'Ya canjeaste un código antes.';
        case 'account_too_old':
          return 'Los códigos solo se canjean en cuentas nuevas.';
        case 'invalid_code':
          return 'Código inválido.';
        case 'self':
          return 'No puedes usar tu propio código.';
        default:
          return 'No se pudo canjear el código.';
      }
    } catch (e) {
      debugPrint('ReferralService.redeem error: $e');
      return 'No se pudo canjear el código.';
    }
  }
}
