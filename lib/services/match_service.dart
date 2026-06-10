import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_model.dart';
import 'notification_service.dart';

/// Servicio de Match Mode 1v1.
/// Toda la lógica de juego vive en RPCs SECURITY DEFINER del servidor.
/// El cliente envía acciones y escucha el estado vía Realtime.
class MatchService {
  static final MatchService instance = MatchService._();
  MatchService._();

  final _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Acciones (RPC)
  // ---------------------------------------------------------------------------

  /// Envía un desafío a un amigo. Devuelve el id del desafío o lanza con
  /// un mensaje legible si falla la regla de negocio.
  Future<String> sendChallenge(String challengedId) async {
    try {
      final res = await _client.rpc(
        'send_match_challenge',
        params: {'p_challenged_id': challengedId},
      );
      // Push best-effort, fire-and-forget para no bloquear la UI.
      unawaited(_notifyChallenge(challengedId));
      return res as String;
    } on PostgrestException catch (e) {
      throw MatchException(_humanizeError(e.message));
    } catch (e) {
      debugPrint('MatchService.sendChallenge error: $e');
      throw MatchException('No se pudo enviar el desafío.');
    }
  }

  /// Responde un desafío. Si se acepta, devuelve el matchId de la partida.
  Future<String?> respondToChallenge(String challengeId, bool accept) async {
    try {
      final res = await _client.rpc(
        'respond_to_challenge',
        params: {'p_challenge_id': challengeId, 'p_accept': accept},
      );
      return res as String?;
    } on PostgrestException catch (e) {
      throw MatchException(_humanizeError(e.message));
    } catch (e) {
      debugPrint('MatchService.respondToChallenge error: $e');
      throw MatchException('No se pudo responder al desafío.');
    }
  }

  /// Registra el peso y reps del usuario en la ronda actual.
  Future<void> submitRound(String matchId, double weight, int reps) async {
    try {
      await _client.rpc('submit_match_round', params: {
        'p_match_id': matchId,
        'p_weight': weight,
        'p_reps': reps,
      });
    } on PostgrestException catch (e) {
      throw MatchException(_humanizeError(e.message));
    } catch (e) {
      debugPrint('MatchService.submitRound error: $e');
      throw MatchException('No se pudo registrar el resultado.');
    }
  }

  /// Abandona la partida (el rival gana de inmediato).
  Future<void> forfeit(String matchId) async {
    try {
      await _client.rpc('forfeit_match', params: {'p_match_id': matchId});
    } catch (e) {
      debugPrint('MatchService.forfeit error: $e');
    }
  }

  /// Reclama victoria por inactividad. Solo aplica si el rival no envió su
  /// marca en el tiempo límite (7 min). Devuelve true si se aplicó.
  Future<bool> claimTimeout(String matchId) async {
    try {
      final res = await _client.rpc(
        'timeout_match',
        params: {'p_match_id': matchId},
      );
      return res == true;
    } catch (e) {
      debugPrint('MatchService.claimTimeout error: $e');
      return false;
    }
  }

  /// Segundos máximos por turno antes de que el rival pueda reclamar victoria.
  static const int turnTimeoutSeconds = 420;

  // ---------------------------------------------------------------------------
  // Lectura
  // ---------------------------------------------------------------------------

  /// Desafíos pendientes recibidos por el usuario actual (con perfil del retador).
  Future<List<MatchChallenge>> getIncomingChallenges() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('match_challenges')
          .select('id, challenger_id, challenged_id, status, match_id, created_at')
          .eq('challenged_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return [];

      final challengerIds =
          list.map((r) => r['challenger_id'] as String).toSet().toList();
      final players = await _fetchPlayers(challengerIds);

      return list
          .map((r) => MatchChallenge.fromMap(r,
              challenger: players[r['challenger_id'] as String]))
          .toList();
    } catch (e) {
      debugPrint('MatchService.getIncomingChallenges error: $e');
      return [];
    }
  }

  /// Amigos a los que puedo desafiar: usuarios con follow mutuo
  /// (yo los sigo y ellos me siguen). Devueltos con su tier.
  Future<List<MatchPlayer>> getChallengeableFriends() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final followingRows = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);
      final followersRows = await _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', uid);

      final following = List<Map<String, dynamic>>.from(followingRows)
          .map((r) => r['following_id'] as String?)
          .whereType<String>()
          .toSet();
      final followers = List<Map<String, dynamic>>.from(followersRows)
          .map((r) => r['follower_id'] as String?)
          .whereType<String>()
          .toSet();

      final mutualIds = following.intersection(followers).toList();
      if (mutualIds.isEmpty) return [];

      final players = await _fetchPlayers(mutualIds);
      final list = players.values.toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('MatchService.getChallengeableFriends error: $e');
      return [];
    }
  }

  /// Cuenta de desafíos pendientes (para el badge en ranked).
  Future<int> getIncomingChallengeCount() async {
    final uid = currentUserId;
    if (uid == null) return 0;
    try {
      final rows = await _client
          .from('match_challenges')
          .select('id')
          .eq('challenged_id', uid)
          .eq('status', 'pending');
      return (rows as List).length;
    } catch (e) {
      debugPrint('MatchService.getIncomingChallengeCount error: $e');
      return 0;
    }
  }

  /// Carga el estado completo de la partida (match + rondas + jugadores + ejercicios).
  Future<MatchState?> getMatchState(String matchId) async {
    try {
      final matchRow = await _client
          .from('matches')
          .select(
              'id, player_a, player_b, status, current_round, current_turn, wins_a, wins_b, winner_id, rp_delta_a, rp_delta_b, turn_started_at')
          .eq('id', matchId)
          .maybeSingle();
      if (matchRow == null) return null;
      final match = Match.fromMap(matchRow);

      final roundRows = await _client
          .from('match_rounds')
          .select(
              'id, round_number, exercise_id, weight_a, reps_a, score_a, weight_b, reps_b, score_b, round_winner')
          .eq('match_id', matchId)
          .order('round_number', ascending: true);
      final rounds = List<Map<String, dynamic>>.from(roundRows)
          .map(MatchRound.fromMap)
          .toList();

      final players = await _fetchPlayers([match.playerA, match.playerB]);
      final exerciseNames =
          await _fetchExerciseNames(rounds.map((r) => r.exerciseId).toList());

      return MatchState(
        match: match,
        rounds: rounds,
        playerA: players[match.playerA] ??
            MatchPlayer(userId: match.playerA, username: 'Jugador A'),
        playerB: players[match.playerB] ??
            MatchPlayer(userId: match.playerB, username: 'Jugador B'),
        exerciseNames: exerciseNames,
      );
    } catch (e) {
      debugPrint('MatchService.getMatchState error: $e');
      return null;
    }
  }

  /// Stream del estado de la partida. Re-consulta el estado completo ante
  /// cualquier cambio en `matches` o `match_rounds` de este match.
  Stream<MatchState> watchMatch(String matchId) {
    final controller = StreamController<MatchState>();
    RealtimeChannel? channel;

    Future<void> push() async {
      final state = await getMatchState(matchId);
      if (state != null && !controller.isClosed) controller.add(state);
    }

    controller.onListen = () {
      push();
      channel = _client.channel('match:$matchId');
      channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: matchId,
            ),
            callback: (_) => push(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'match_rounds',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'match_id',
              value: matchId,
            ),
            callback: (_) => push(),
          )
          .subscribe();
    };

    controller.onCancel = () async {
      if (channel != null) {
        await _client.removeChannel(channel!);
      }
      await controller.close();
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Fórmula de puntaje (espejo cliente para mostrar estimación al usuario).
  /// Epley relativo al peso corporal. El valor oficial lo calcula el servidor.
  static double previewScore({
    required double weight,
    required int reps,
    required double bodyWeight,
  }) {
    if (bodyWeight <= 0) return 0;
    final raw = (weight * (1 + reps / 30.0)) / bodyWeight * 100;
    return double.parse(raw.toStringAsFixed(2));
  }

  Future<void> _notifyChallenge(String challengedId) async {
    try {
      final myName = await _myUsername();
      await NotificationService.instance.sendPushToUser(
        userId: challengedId,
        title: 'Nuevo desafío 1v1 ⚔️',
        body: myName != null
            ? '@$myName te retó a un duelo. Entra a Ranked para responder.'
            : 'Alguien te retó a un duelo. Entra a Ranked para responder.',
        data: const {'type': 'match_challenge'},
      );
    } catch (e) {
      debugPrint('MatchService._notifyChallenge error: $e');
    }
  }

  Future<String?> _myUsername() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('username')
          .eq('id', uid)
          .maybeSingle();
      return row?['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, MatchPlayer>> _fetchPlayers(List<String> ids) async {
    if (ids.isEmpty) return {};
    final result = <String, MatchPlayer>{};
    try {
      final profileRows = await _client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .inFilter('id', ids);
      final rankedRows = await _client
          .from('user_ranked_profile')
          .select('user_id, current_tier')
          .inFilter('user_id', ids);
      final tierById = <String, String>{
        for (final r in List<Map<String, dynamic>>.from(rankedRows))
          r['user_id'] as String: (r['current_tier'] as String?) ?? 'hierro',
      };
      for (final p in List<Map<String, dynamic>>.from(profileRows)) {
        final id = p['id'] as String;
        result[id] = MatchPlayer.fromMap(p, tierRaw: tierById[id]);
      }
    } catch (e) {
      debugPrint('MatchService._fetchPlayers error: $e');
    }
    return result;
  }

  Future<Map<String, String>> _fetchExerciseNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _client
          .from('exercise_catalog')
          .select('id, name_es')
          .inFilter('id', ids);
      return {
        for (final r in List<Map<String, dynamic>>.from(rows))
          r['id'] as String: (r['name_es'] as String?) ?? 'Ejercicio',
      };
    } catch (e) {
      debugPrint('MatchService._fetchExerciseNames error: $e');
      return {};
    }
  }

  String _humanizeError(String raw) {
    if (raw.contains('must be mutual followers')) {
      return 'Solo puedes desafiar a un amigo (que te siga y lo sigas).';
    }
    if (raw.contains('must follow')) {
      return 'Solo puedes desafiar a alguien que sigues.';
    }
    if (raw.contains('pending challenge already exists')) {
      return 'Ya hay un desafío pendiente con esta persona.';
    }
    if (raw.contains('cannot challenge yourself')) {
      return 'No puedes desafiarte a ti mismo.';
    }
    if (raw.contains('not your turn')) {
      return 'No es tu turno todavía.';
    }
    if (raw.contains('not enough eligible exercises')) {
      return 'No hay suficientes ejercicios disponibles.';
    }
    if (raw.contains('match not active')) {
      return 'Esta partida ya terminó.';
    }
    if (raw.contains('not a participant')) {
      return 'No participas en esta partida.';
    }
    if (raw.contains('invalid weight')) {
      return 'Peso fuera de rango.';
    }
    if (raw.contains('invalid reps')) {
      return 'Reps fuera de rango.';
    }
    if (raw.contains('no autorizado')) {
      return 'No tienes permiso para esta acción.';
    }
    return 'Algo salió mal. Inténtalo de nuevo.';
  }
}

class MatchException implements Exception {
  final String message;
  MatchException(this.message);
  @override
  String toString() => message;
}
