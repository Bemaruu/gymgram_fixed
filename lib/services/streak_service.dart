import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/streak_model.dart';

/// Servicio de rachas de entrenamiento. Toda la lógica vive en el RPC
/// `bump_workout_streak` (server-side, consciente de días de descanso). El
/// cliente solo dispara la actualización y lee la tabla `user_streaks`.
class StreakService {
  static final StreakService instance = StreakService._();
  StreakService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Fecha local de hoy en formato yyyy-MM-dd (NO UTC: la racha depende del día
  /// local del usuario, no del día del servidor).
  String _localToday() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Recalcula y devuelve la racha tras completar el entrenamiento de hoy.
  /// Debe llamarse después de que el workout_log del día ya exista.
  /// Devuelve null si falla (la UI degrada sin romper el flujo de entreno).
  Future<StreakModel?> bumpAfterWorkout() async {
    if (_uid == null) return null;
    try {
      final res = await _client.rpc(
        'bump_workout_streak',
        params: {'p_local_date': _localToday()},
      );
      if (res is Map) {
        return StreakModel.fromMap(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('bumpAfterWorkout error: $e');
      return null;
    }
  }

  /// Lee la racha de un usuario (la propia si [userId] es null). Devuelve
  /// [StreakModel.empty] si no hay fila o falla la lectura.
  Future<StreakModel> getStreak([String? userId]) async {
    final uid = userId ?? _uid;
    if (uid == null) return StreakModel.empty;
    try {
      final row = await _client
          .from('user_streaks')
          .select(
            'current_streak, best_streak, last_workout_date, freeze_tokens, total_workouts',
          )
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return StreakModel.empty;
      return StreakModel.fromMap(row);
    } catch (e) {
      if (kDebugMode) debugPrint('getStreak error: $e');
      return StreakModel.empty;
    }
  }
}
