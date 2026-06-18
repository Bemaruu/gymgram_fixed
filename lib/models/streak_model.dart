/// Estado de la racha de entrenamiento de un usuario.
///
/// La racha cuenta días de entrenamiento programados completados. Los días de
/// descanso (sin rutina ese día) no suman pero tampoco rompen la racha; solo se
/// rompe al saltarse un día de entrenamiento programado.
class StreakModel {
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastWorkoutDate;
  final int freezeTokens;
  final int totalWorkouts;

  /// Solo viene poblado en la respuesta de [bump_workout_streak]: indica que la
  /// racha actual superó el récord histórico en esta actualización.
  final bool isNewRecord;

  const StreakModel({
    required this.currentStreak,
    required this.bestStreak,
    this.lastWorkoutDate,
    this.freezeTokens = 0,
    this.totalWorkouts = 0,
    this.isNewRecord = false,
  });

  static const empty = StreakModel(currentStreak: 0, bestStreak: 0);

  factory StreakModel.fromMap(Map<String, dynamic> map) {
    final rawDate = map['last_workout_date'];
    return StreakModel(
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      bestStreak: (map['best_streak'] as num?)?.toInt() ?? 0,
      lastWorkoutDate:
          rawDate is String && rawDate.isNotEmpty ? DateTime.tryParse(rawDate) : null,
      freezeTokens: (map['freeze_tokens'] as num?)?.toInt() ?? 0,
      totalWorkouts: (map['total_workouts'] as num?)?.toInt() ?? 0,
      isNewRecord: map['is_new_record'] == true,
    );
  }

  bool get hasStreak => currentStreak > 0;

  /// Siguiente hito de medalla por racha (alineado con el catálogo de medallas
  /// existente: 7 / 14 / 30 / 60 / 90 días). Devuelve null si ya superó todos.
  int? get nextMilestone {
    const milestones = [7, 14, 30, 60, 90];
    for (final m in milestones) {
      if (currentStreak < m) return m;
    }
    return null;
  }
}
