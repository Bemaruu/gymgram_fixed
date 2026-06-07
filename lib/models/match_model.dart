// Modelos de Match Mode 1v1 (duelo competitivo entre amigos).
// El servidor mantiene la verdad (RPCs SECURITY DEFINER). El cliente solo lee.

import '../models/ranked_profile_model.dart' show RankedTier;

enum MatchStatus { active, finished, abandoned }

MatchStatus _parseStatus(String? raw) {
  switch (raw) {
    case 'finished':
      return MatchStatus.finished;
    case 'abandoned':
      return MatchStatus.abandoned;
    case 'active':
    default:
      return MatchStatus.active;
  }
}

/// Resumen de un jugador para mostrar en la UI (avatar, nombre, tier).
class MatchPlayer {
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final RankedTier tier;

  const MatchPlayer({
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.tier = RankedTier.hierro,
  });

  String get label => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!
      : username;

  factory MatchPlayer.fromMap(Map<String, dynamic> m, {String? tierRaw}) {
    return MatchPlayer(
      userId: m['id'] as String,
      username: (m['username'] as String?) ?? '',
      displayName: m['full_name'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      tier: _tierFromRaw(tierRaw),
    );
  }

  static RankedTier _tierFromRaw(String? raw) {
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
}

/// Desafío entrante/saliente.
class MatchChallenge {
  final String id;
  final String challengerId;
  final String challengedId;
  final String status;
  final String? matchId;
  final DateTime? createdAt;
  final MatchPlayer? challenger; // perfil del retador (para mostrar)

  const MatchChallenge({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    required this.status,
    this.matchId,
    this.createdAt,
    this.challenger,
  });

  factory MatchChallenge.fromMap(Map<String, dynamic> m, {MatchPlayer? challenger}) {
    return MatchChallenge(
      id: m['id'] as String,
      challengerId: m['challenger_id'] as String,
      challengedId: m['challenged_id'] as String,
      status: (m['status'] as String?) ?? 'pending',
      matchId: m['match_id'] as String?,
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      challenger: challenger,
    );
  }
}

/// Una ronda del duelo.
class MatchRound {
  final String id;
  final int roundNumber;
  final String exerciseId;
  final double? weightA;
  final int? repsA;
  final double? scoreA;
  final double? weightB;
  final int? repsB;
  final double? scoreB;
  final String? roundWinner; // 'a' | 'b' | 'tie'

  const MatchRound({
    required this.id,
    required this.roundNumber,
    required this.exerciseId,
    this.weightA,
    this.repsA,
    this.scoreA,
    this.weightB,
    this.repsB,
    this.scoreB,
    this.roundWinner,
  });

  bool get submittedA => scoreA != null;
  bool get submittedB => scoreB != null;
  bool get bothSubmitted => submittedA && submittedB;

  factory MatchRound.fromMap(Map<String, dynamic> m) {
    return MatchRound(
      id: m['id'] as String,
      roundNumber: (m['round_number'] as num).toInt(),
      exerciseId: m['exercise_id'] as String,
      weightA: (m['weight_a'] as num?)?.toDouble(),
      repsA: (m['reps_a'] as num?)?.toInt(),
      scoreA: (m['score_a'] as num?)?.toDouble(),
      weightB: (m['weight_b'] as num?)?.toDouble(),
      repsB: (m['reps_b'] as num?)?.toInt(),
      scoreB: (m['score_b'] as num?)?.toDouble(),
      roundWinner: m['round_winner'] as String?,
    );
  }
}

/// Estado completo de la partida.
class Match {
  final String id;
  final String playerA;
  final String playerB;
  final MatchStatus status;
  final int currentRound;
  final String currentTurn; // 'a' | 'b'
  final int winsA;
  final int winsB;
  final String? winnerId;
  final int? rpDeltaA;
  final int? rpDeltaB;
  final DateTime? turnStartedAt;

  const Match({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.status,
    required this.currentRound,
    required this.currentTurn,
    required this.winsA,
    required this.winsB,
    this.winnerId,
    this.rpDeltaA,
    this.rpDeltaB,
    this.turnStartedAt,
  });

  factory Match.fromMap(Map<String, dynamic> m) {
    return Match(
      id: m['id'] as String,
      playerA: m['player_a'] as String,
      playerB: m['player_b'] as String,
      status: _parseStatus(m['status'] as String?),
      currentRound: (m['current_round'] as num?)?.toInt() ?? 1,
      currentTurn: (m['current_turn'] as String?) ?? 'a',
      winsA: (m['wins_a'] as num?)?.toInt() ?? 0,
      winsB: (m['wins_b'] as num?)?.toInt() ?? 0,
      winnerId: m['winner_id'] as String?,
      rpDeltaA: (m['rp_delta_a'] as num?)?.toInt(),
      rpDeltaB: (m['rp_delta_b'] as num?)?.toInt(),
      turnStartedAt: DateTime.tryParse(m['turn_started_at']?.toString() ?? ''),
    );
  }
}

/// Snapshot agregado que consume la UI del duelo.
class MatchState {
  final Match match;
  final List<MatchRound> rounds;
  final MatchPlayer playerA;
  final MatchPlayer playerB;
  final Map<String, String> exerciseNames; // exerciseId -> nombre

  const MatchState({
    required this.match,
    required this.rounds,
    required this.playerA,
    required this.playerB,
    required this.exerciseNames,
  });

  MatchRound? get currentRound {
    for (final r in rounds) {
      if (r.roundNumber == match.currentRound) return r;
    }
    return rounds.isNotEmpty ? rounds.last : null;
  }

  String exerciseNameFor(MatchRound? r) =>
      r == null ? '' : (exerciseNames[r.exerciseId] ?? 'Ejercicio');
}
