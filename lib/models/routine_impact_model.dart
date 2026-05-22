class RoutineImpact {
  final String routineId;
  final int totalCopies;
  final int totalWorkoutsViaCopy;
  final int totalUsersTierUpgraded;

  const RoutineImpact({
    required this.routineId,
    required this.totalCopies,
    required this.totalWorkoutsViaCopy,
    required this.totalUsersTierUpgraded,
  });

  factory RoutineImpact.fromMap(Map<String, dynamic> map) {
    return RoutineImpact(
      routineId: map['routine_id'] as String,
      totalCopies: (map['total_copies'] as num?)?.toInt() ?? 0,
      totalWorkoutsViaCopy:
          (map['total_workouts_completed_via_copy'] as num?)?.toInt() ?? 0,
      totalUsersTierUpgraded:
          (map['total_users_tier_upgraded'] as num?)?.toInt() ?? 0,
    );
  }
}
