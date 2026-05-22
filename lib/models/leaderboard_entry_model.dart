import 'ranked_profile_model.dart';

class LeaderboardEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final RankedTier tier;
  final int? division;
  final int currentRp;
  final int globalRank;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.tier,
    required this.division,
    required this.currentRp,
    required this.globalRank,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      userId: map['user_id'] as String,
      username: (map['username'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
      tier: _parseTier(map['current_tier'] as String?),
      division: (map['current_division'] as num?)?.toInt(),
      currentRp: (map['current_rp'] as num?)?.toInt() ?? 0,
      globalRank: (map['global_rank'] as num?)?.toInt() ?? 0,
    );
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
}
