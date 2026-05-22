import 'ranked_profile_model.dart';

class SeasonReward {
  final String id;
  final String userId;
  final String seasonId;
  final RankedTier? finalTier;
  final int? finalDivision;
  final int? finalRp;
  final String? medalKey;
  final String? frameKey;
  final DateTime? bannerUntil;
  final int? inmortalRank;
  final DateTime awardedAt;

  const SeasonReward({
    required this.id,
    required this.userId,
    required this.seasonId,
    required this.finalTier,
    required this.finalDivision,
    required this.finalRp,
    required this.medalKey,
    required this.frameKey,
    required this.bannerUntil,
    required this.inmortalRank,
    required this.awardedAt,
  });

  factory SeasonReward.fromMap(Map<String, dynamic> map) {
    return SeasonReward(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      seasonId: map['season_id'] as String,
      finalTier: _parseTier(map['final_tier'] as String?),
      finalDivision: (map['final_division'] as num?)?.toInt(),
      finalRp: (map['final_rp'] as num?)?.toInt(),
      medalKey: map['medal_key'] as String?,
      frameKey: map['frame_key'] as String?,
      bannerUntil: _parseDate(map['banner_until']),
      inmortalRank: (map['inmortal_rank'] as num?)?.toInt(),
      awardedAt: _parseDate(map['awarded_at']) ?? DateTime.now(),
    );
  }

  static RankedTier? _parseTier(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case 'hierro':
        return RankedTier.hierro;
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
    }
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
