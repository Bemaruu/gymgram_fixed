import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/models/streak_model.dart';

void main() {
  group('StreakModel.fromMap', () {
    test('parsea la respuesta de bump_workout_streak', () {
      final m = StreakModel.fromMap({
        'current_streak': 14,
        'best_streak': 31,
        'last_workout_date': '2026-06-17',
        'freeze_tokens': 2,
        'total_workouts': 40,
        'is_new_record': false,
      });
      expect(m.currentStreak, 14);
      expect(m.bestStreak, 31);
      expect(m.lastWorkoutDate, DateTime(2026, 6, 17));
      expect(m.freezeTokens, 2);
      expect(m.totalWorkouts, 40);
      expect(m.isNewRecord, isFalse);
      expect(m.hasStreak, isTrue);
    });

    test('tolera campos nulos/ausentes sin romper', () {
      final m = StreakModel.fromMap({});
      expect(m.currentStreak, 0);
      expect(m.bestStreak, 0);
      expect(m.lastWorkoutDate, isNull);
      expect(m.freezeTokens, 0);
      expect(m.totalWorkouts, 0);
      expect(m.hasStreak, isFalse);
    });

    test('last_workout_date vacío => null', () {
      final m = StreakModel.fromMap({'current_streak': 0, 'last_workout_date': ''});
      expect(m.lastWorkoutDate, isNull);
    });

    test('is_new_record true se detecta', () {
      final m = StreakModel.fromMap({'current_streak': 5, 'is_new_record': true});
      expect(m.isNewRecord, isTrue);
    });
  });

  group('StreakModel.nextMilestone', () {
    test('hitos alineados con el catálogo de medallas (7/14/30/60/90)', () {
      expect(const StreakModel(currentStreak: 0, bestStreak: 0).nextMilestone, 7);
      expect(const StreakModel(currentStreak: 6, bestStreak: 6).nextMilestone, 7);
      expect(const StreakModel(currentStreak: 7, bestStreak: 7).nextMilestone, 14);
      expect(const StreakModel(currentStreak: 20, bestStreak: 20).nextMilestone, 30);
      expect(const StreakModel(currentStreak: 89, bestStreak: 89).nextMilestone, 90);
    });

    test('null cuando ya superó el máximo hito', () {
      expect(const StreakModel(currentStreak: 90, bestStreak: 90).nextMilestone, isNull);
      expect(const StreakModel(currentStreak: 365, bestStreak: 365).nextMilestone, isNull);
    });
  });
}
