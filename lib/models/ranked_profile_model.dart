// Modelo de perfil Ranked. Fase 1.
// El servidor mantiene la verdad (recalculate_user_rank). Esto solo lee.

enum RankedTier { hierro, bronce, plata, oro, platino, diamante, inmortal }

class RankedProfile {
  final RankedTier tier;
  final int? division; // null para inmortal; 3=III, 2=II, 1=I
  final int currentRp;
  final int strengthScore;
  final int consistencyScore;
  final int communityScore;
  final int challengeScore;
  final DateTime? lastRecalcAt;

  const RankedProfile({
    required this.tier,
    required this.division,
    required this.currentRp,
    required this.strengthScore,
    required this.consistencyScore,
    required this.communityScore,
    required this.challengeScore,
    this.lastRecalcAt,
  });

  factory RankedProfile.fromMap(Map<String, dynamic> map) {
    return RankedProfile(
      tier: _parseTier(map['current_tier'] as String?),
      division: (map['current_division'] as num?)?.toInt(),
      currentRp: (map['current_rp'] as num?)?.toInt() ?? 0,
      strengthScore: (map['strength_score'] as num?)?.toInt() ?? 0,
      consistencyScore: (map['consistency_score'] as num?)?.toInt() ?? 0,
      communityScore: (map['community_score'] as num?)?.toInt() ?? 0,
      challengeScore: (map['challenge_score'] as num?)?.toInt() ?? 0,
      lastRecalcAt: _parseDate(map['last_recalc_at']),
    );
  }

  String tierLabel() {
    switch (tier) {
      case RankedTier.hierro:
        return 'Hierro';
      case RankedTier.bronce:
        return 'Bronce';
      case RankedTier.plata:
        return 'Plata';
      case RankedTier.oro:
        return 'Oro';
      case RankedTier.platino:
        return 'Platino';
      case RankedTier.diamante:
        return 'Diamante';
      case RankedTier.inmortal:
        return 'Inmortal';
    }
  }

  String romanDivision() {
    if (division == null) return '';
    switch (division) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      default:
        return '';
    }
  }

  /// Rango (lo, hi) de RP para el tier actual.
  /// Para inmortal devuelve (6000, 6000) (sin tope).
  (int, int) tierRange() {
    switch (tier) {
      case RankedTier.hierro:
        return (0, 400);
      case RankedTier.bronce:
        return (400, 1000);
      case RankedTier.plata:
        return (1000, 1800);
      case RankedTier.oro:
        return (1800, 2800);
      case RankedTier.platino:
        return (2800, 4000);
      case RankedTier.diamante:
        return (4000, 6000);
      case RankedTier.inmortal:
        return (6000, 6000);
    }
  }

  /// Progreso 0..1 dentro del tier actual hacia el siguiente.
  double progressToNextTier() {
    final (lo, hi) = tierRange();
    if (hi <= lo) return 1.0;
    final p = (currentRp - lo) / (hi - lo);
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
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

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

class RankedSeason {
  final String id;
  final String name;
  final String slug;
  final String? themeLabel;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int totalWeeks;

  const RankedSeason({
    required this.id,
    required this.name,
    required this.slug,
    required this.themeLabel,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.totalWeeks,
  });

  factory RankedSeason.fromMap(Map<String, dynamic> map) {
    return RankedSeason(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      slug: (map['slug'] as String?) ?? '',
      themeLabel: map['theme_label'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isActive: (map['is_active'] as bool?) ?? false,
      totalWeeks: (map['total_weeks'] as num?)?.toInt() ?? 12,
    );
  }
}
