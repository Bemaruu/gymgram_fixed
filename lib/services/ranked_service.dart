import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ranked_profile_model.dart';
import '../models/weekly_mission_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../models/routine_impact_model.dart';
import '../models/season_reward_model.dart';
import '../models/season_recap_model.dart';

/// Servicio Ranked (Fase 2).
class RankedService {
  static final RankedService instance = RankedService._();
  RankedService._();

  final _client = Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Expone el uid actual sin filtrar el cliente. Util para UI.
  String? get currentUserId => _uid;

  Future<RankedProfile?> getMyProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    return getProfileOf(uid);
  }

  Future<RankedProfile?> getProfileOf(String userId) async {
    try {
      final row = await _client
          .from('user_ranked_profile')
          .select(
            'current_tier, current_division, current_rp, '
            'strength_score, consistency_score, community_score, '
            'challenge_score, last_recalc_at',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return RankedProfile.fromMap(row);
    } catch (e) {
      debugPrint('RankedService.getProfileOf error: $e');
      return null;
    }
  }

  Future<RankedSeason?> getActiveSeason() async {
    try {
      final row = await _client
          .from('ranked_seasons')
          .select(
              'id, name, slug, theme_label, start_date, end_date, is_active, total_weeks')
          .eq('is_active', true)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return RankedSeason.fromMap(row);
    } catch (e) {
      debugPrint('RankedService.getActiveSeason error: $e');
      return null;
    }
  }

  Future<void> recalculateMyRank() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.rpc('recalculate_user_rank', params: {'p_user_id': uid});
    } catch (e) {
      debugPrint('RankedService.recalculateMyRank error: $e');
    }
  }

  /// Misiones semanales de la temporada activa, con progreso del usuario.
  Future<List<WeeklyMission>> getWeeklyMissions({int? weekNumber}) async {
    final uid = _uid;
    try {
      final season = await getActiveSeason();
      if (season == null) return const [];

      var query = _client
          .from('weekly_missions')
          .select(
              'id, key, title, description, target_value, rp_reward, category, difficulty, week_number')
          .eq('season_id', season.id);
      if (weekNumber != null) {
        query = query.eq('week_number', weekNumber);
      }
      final missions = await query.order('week_number', ascending: true);

      Map<String, Map<String, dynamic>> progressByMission = {};
      if (uid != null) {
        try {
          final prog = await _client
              .from('user_mission_progress')
              .select('mission_id, progress_value, completed_at')
              .eq('user_id', uid);
          for (final row in (prog as List)) {
            final m = row as Map<String, dynamic>;
            progressByMission[m['mission_id'] as String] = m;
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[RankedService.getWeeklyMissions] progress fetch error: $e');
        }
      }

      return (missions as List).map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        final p = progressByMission[m['id']];
        if (p != null) {
          m['progress_value'] = p['progress_value'];
          m['completed_at'] = p['completed_at'];
        }
        return WeeklyMission.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('RankedService.getWeeklyMissions error: $e');
      return const [];
    }
  }

  /// Leaderboard global (de la temporada activa).
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final rows = await _client
          .from('ranked_leaderboard_view')
          .select(
              'user_id, username, avatar_url, current_tier, current_division, current_rp, global_rank')
          .order('global_rank', ascending: true)
          .range(offset, offset + limit - 1);
      return (rows as List)
          .map((r) =>
              LeaderboardEntry.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('RankedService.getGlobalLeaderboard error: $e');
      return const [];
    }
  }

  /// Leaderboard de amigos. Usa la tabla `follows` (follower_id -> following_id).
  /// Considera "amigos" a los usuarios que YO sigo (follower_id = uid).
  Future<List<LeaderboardEntry>> getFriendsLeaderboard({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final follows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);
      final ids = <String>[
        uid,
        ...((follows as List)
            .map((r) => (r as Map)['following_id'] as String?)
            .whereType<String>()),
      ];
      if (ids.isEmpty) return const [];

      final rows = await _client
          .from('ranked_leaderboard_view')
          .select(
              'user_id, username, avatar_url, current_tier, current_division, current_rp, global_rank')
          .inFilter('user_id', ids)
          .order('current_rp', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) =>
              LeaderboardEntry.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('RankedService.getFriendsLeaderboard error: $e');
      return const [];
    }
  }

  /// Impacto comunitario de una rutina.
  Future<RoutineImpact?> getRoutineImpact(String routineId) async {
    try {
      final row = await _client
          .from('routine_impact_stats')
          .select(
              'routine_id, total_copies, total_workouts_completed_via_copy, total_users_tier_upgraded')
          .eq('routine_id', routineId)
          .maybeSingle();
      if (row == null) return null;
      return RoutineImpact.fromMap(row);
    } catch (e) {
      debugPrint('RankedService.getRoutineImpact error: $e');
      return null;
    }
  }

  /// Impacto agregado de TODAS las rutinas del usuario actual.
  /// Suma copias, workouts via copia y tier-ups inspirados.
  Future<RoutineImpact?> getMyAggregatedImpact() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final routines =
          await _client.from('routines').select('id').eq('user_id', uid);
      final ids = (routines as List)
          .map((r) => (r as Map)['id'] as String?)
          .whereType<String>()
          .toList();
      if (ids.isEmpty) {
        return const RoutineImpact(
          routineId: '',
          totalCopies: 0,
          totalWorkoutsViaCopy: 0,
          totalUsersTierUpgraded: 0,
        );
      }
      final rows = await _client
          .from('routine_impact_stats')
          .select(
              'total_copies, total_workouts_completed_via_copy, total_users_tier_upgraded')
          .inFilter('routine_id', ids);
      int copies = 0;
      int viaCopy = 0;
      int tierUps = 0;
      for (final row in (rows as List)) {
        final m = row as Map;
        copies += (m['total_copies'] as num?)?.toInt() ?? 0;
        viaCopy +=
            (m['total_workouts_completed_via_copy'] as num?)?.toInt() ?? 0;
        tierUps += (m['total_users_tier_upgraded'] as num?)?.toInt() ?? 0;
      }
      return RoutineImpact(
        routineId: '',
        totalCopies: copies,
        totalWorkoutsViaCopy: viaCopy,
        totalUsersTierUpgraded: tierUps,
      );
    } catch (e) {
      debugPrint('RankedService.getMyAggregatedImpact error: $e');
      return null;
    }
  }

  /// Historial de temporadas (medallas) de un usuario (default: yo).
  Future<List<SeasonReward>> getSeasonHistory({String? userId}) async {
    final id = userId ?? _uid;
    if (id == null) return const [];
    try {
      final rows = await _client
          .from('season_rewards')
          .select(
              'id, user_id, season_id, final_tier, final_division, final_rp, medal_key, frame_key, banner_until, inmortal_rank, awarded_at')
          .eq('user_id', id)
          .order('awarded_at', ascending: false);
      return (rows as List)
          .map((r) => SeasonReward.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('RankedService.getSeasonHistory error: $e');
      return const [];
    }
  }

  /// Recap para la pantalla fin de temporada.
  /// Si no hay reward (temporada aún activa) usa el perfil ranked actual.
  Future<SeasonRecap?> getMySeasonRecap(String seasonId) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      // 1) Datos base de la temporada
      final season = await _client
          .from('ranked_seasons')
          .select('id, name, slug, start_date, end_date')
          .eq('id', seasonId)
          .maybeSingle();
      if (season == null) return null;
      final startDate =
          DateTime.tryParse(season['start_date'] as String) ?? DateTime.now();

      // 2) Tier final: reward si existe, sino perfil actual
      RankedTier tier = RankedTier.hierro;
      int? division = 3;
      int finalRp = 0;

      try {
        final reward = await _client
            .from('season_rewards')
            .select('final_tier, final_division, final_rp')
            .eq('user_id', uid)
            .eq('season_id', seasonId)
            .maybeSingle();
        if (reward != null) {
          tier = _parseTier(reward['final_tier'] as String?);
          division = (reward['final_division'] as num?)?.toInt();
          finalRp = (reward['final_rp'] as num?)?.toInt() ?? 0;
        } else {
          final profile = await getMyProfile();
          if (profile != null) {
            tier = profile.tier;
            division = profile.division;
            finalRp = profile.currentRp;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[RankedService.getMySeasonRecap] reward fetch error: $e');
      }

      // 3) Stats agregadas
      int daysTrained = 0;
      int prs = 0;
      int usersInspired = 0;

      try {
        final logs = await _client
            .from('workout_logs')
            .select('logged_at')
            .eq('user_id', uid)
            .gte('logged_at', startDate.toIso8601String().substring(0, 10));
        daysTrained = (logs as List)
            .map((r) => (r as Map)['logged_at'] as String?)
            .whereType<String>()
            .toSet()
            .length;
      } catch (e) {
        if (kDebugMode) debugPrint('[RankedService.getMySeasonRecap] workout_logs error: $e');
      }

      try {
        final prsRows = await _client
            .from('user_strength_records')
            .select('id, achieved_at')
            .eq('user_id', uid)
            .gte('achieved_at', startDate.toIso8601String());
        prs = (prsRows as List).length;
      } catch (e) {
        if (kDebugMode) debugPrint('[RankedService.getMySeasonRecap] strength_records error: $e');
      }

      try {
        // copias recibidas en rutinas propias
        final routines = await _client
            .from('routines')
            .select('id')
            .eq('user_id', uid);
        final routineIds = (routines as List)
            .map((r) => (r as Map)['id'] as String?)
            .whereType<String>()
            .toList();
        if (routineIds.isNotEmpty) {
          final copies = await _client
              .from('routine_copies')
              .select('user_id')
              .inFilter('routine_id', routineIds);
          usersInspired = (copies as List)
              .map((r) => (r as Map)['user_id'] as String?)
              .whereType<String>()
              .toSet()
              .length;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[RankedService.getMySeasonRecap] routine_copies error: $e');
      }

      // 4) Volumen, racha y PRs exactos via RPC get_user_season_stats.
      // Si el RPC existe (migracion aplicada) preferimos sus valores.
      double totalVolumeKg = (daysTrained * 1500).toDouble();
      int longestStreak = _estimateLongestStreak(daysTrained);
      try {
        final stats = await _client.rpc(
          'get_user_season_stats',
          params: {'p_user_id': uid, 'p_season_id': seasonId},
        );
        if (stats is Map) {
          final v = (stats['total_volume_kg'] as num?)?.toDouble();
          if (v != null) totalVolumeKg = v;
          final s = (stats['longest_streak'] as num?)?.toInt();
          if (s != null) longestStreak = s;
          final prCount = (stats['prs_count'] as num?)?.toInt();
          if (prCount != null) prs = prCount;
          final d = (stats['days_trained'] as num?)?.toInt();
          if (d != null) daysTrained = d;
        }
      } catch (e) {
        debugPrint('RankedService.getMySeasonRecap stats rpc fallback: $e');
      }

      // 5) Percentile aprox segun tier
      final percentile = _percentileForTier(tier);

      // 6) Identidad arquetipo en cliente segun scores
      String? identity;
      final profile = await getMyProfile();
      if (profile != null) {
        identity = _identityArchetype(profile);
      }

      return SeasonRecap(
        seasonId: seasonId,
        seasonName: (season['name'] as String?) ?? 'Temporada',
        tier: tier,
        division: division,
        finalRp: finalRp,
        daysTrainedTotal: daysTrained,
        prsAchieved: prs,
        totalVolumeKg: totalVolumeKg,
        longestStreak: longestStreak,
        usersInspired: usersInspired,
        identityArchetype: identity,
        percentile: percentile,
      );
    } catch (e) {
      debugPrint('RankedService.getMySeasonRecap error: $e');
      return null;
    }
  }

  static int _estimateLongestStreak(int daysTrained) {
    // Aproximacion conservadora: ~40% de los dias entrenados podrian ser consecutivos.
    if (daysTrained <= 0) return 0;
    return (daysTrained * 0.4).round().clamp(1, daysTrained);
  }

  static double _percentileForTier(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return 0.30;
      case RankedTier.bronce:
        return 0.55;
      case RankedTier.plata:
        return 0.75;
      case RankedTier.oro:
        return 0.88;
      case RankedTier.platino:
        return 0.95;
      case RankedTier.diamante:
        return 0.98;
      case RankedTier.inmortal:
        return 0.999;
    }
  }

  static RankedTier _parseTier(String? raw) {
    switch (raw) {
      case 'bronce':
        return RankedTier.bronce;
      case 'plata':
        return RankedTier.plata;
      case 'oro':
        return RankedTier.oro;
      case 'platino':
        return RankedTier.platino;
      case 'diamante':
        return RankedTier.diamante;
      case 'inmortal':
        return RankedTier.inmortal;
      case 'hierro':
      default:
        return RankedTier.hierro;
    }
  }

  static String _identityArchetype(RankedProfile p) {
    final s = p.strengthScore;
    final c = p.consistencyScore;
    final co = p.communityScore;
    final ch = p.challengeScore;
    final maxScore = [s, c, co, ch].reduce((a, b) => a > b ? a : b);
    if (maxScore == 0) return 'El Iniciado';
    if (co >= c && co >= s && co >= ch) return 'El Inspirador';
    if (s >= c && s >= co && s >= ch) return 'La Bestia Bajo la Barra';
    if (c >= s && c >= co && c >= ch) return 'El Disciplinado de Hierro';
    if (ch >= s && ch >= c && ch >= co) return 'El Cazador de Desafíos';
    // Mezclas
    if (s > 0 && c > 0 && (s - c).abs() < (s * 0.2)) {
      return 'El Atleta Completo';
    }
    if (co > 0 && c > 0) return 'El Mentor Constante';
    return 'El Silencioso de Pesas Pesadas';
  }
}
