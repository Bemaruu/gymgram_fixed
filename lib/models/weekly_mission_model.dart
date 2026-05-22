// Misión semanal ranked.

enum MissionCategory { strength, consistency, community, challenge }

enum MissionDifficulty { easy, medium, hard }

class WeeklyMission {
  final String id;
  final String key;
  final String title;
  final String description;
  final int targetValue;
  final int currentProgress;
  final bool completed;
  final int rpReward;
  final MissionCategory category;
  final MissionDifficulty difficulty;
  final int weekNumber;

  const WeeklyMission({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentProgress,
    required this.completed,
    required this.rpReward,
    required this.category,
    required this.difficulty,
    required this.weekNumber,
  });

  double get progressPct {
    if (targetValue <= 0) return 0;
    final p = currentProgress / targetValue;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  factory WeeklyMission.fromMap(Map<String, dynamic> map) {
    return WeeklyMission(
      id: map['id'] as String,
      key: (map['key'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      targetValue: (map['target_value'] as num?)?.toInt() ?? 1,
      currentProgress: (map['progress_value'] as num?)?.toInt() ?? 0,
      completed: map['completed_at'] != null,
      rpReward: (map['rp_reward'] as num?)?.toInt() ?? 0,
      category: _parseCategory(map['category'] as String?),
      difficulty: _parseDifficulty(map['difficulty'] as String?),
      weekNumber: (map['week_number'] as num?)?.toInt() ?? 1,
    );
  }

  static MissionCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'strength':
        return MissionCategory.strength;
      case 'community':
        return MissionCategory.community;
      case 'challenge':
        return MissionCategory.challenge;
      case 'consistency':
      default:
        return MissionCategory.consistency;
    }
  }

  static MissionDifficulty _parseDifficulty(String? raw) {
    switch (raw) {
      case 'easy':
        return MissionDifficulty.easy;
      case 'hard':
        return MissionDifficulty.hard;
      case 'medium':
      default:
        return MissionDifficulty.medium;
    }
  }
}
