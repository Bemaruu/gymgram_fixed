import 'ranked_profile_model.dart';

class SeasonRecap {
  final String seasonId;
  final String seasonName;
  final RankedTier tier;
  final int? division;
  final int finalRp;
  final int daysTrainedTotal;
  final int prsAchieved;
  final double totalVolumeKg;
  final int longestStreak;
  final int usersInspired;
  final String? identityArchetype;
  final double percentile;

  const SeasonRecap({
    required this.seasonId,
    required this.seasonName,
    required this.tier,
    required this.division,
    required this.finalRp,
    required this.daysTrainedTotal,
    required this.prsAchieved,
    required this.totalVolumeKg,
    required this.longestStreak,
    required this.usersInspired,
    required this.identityArchetype,
    required this.percentile,
  });
}
