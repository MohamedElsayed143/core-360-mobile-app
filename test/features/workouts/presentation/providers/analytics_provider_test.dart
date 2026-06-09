import 'package:core_360_app/features/workouts/data/models/workout_session_model.dart';
import 'package:core_360_app/features/workouts/presentation/providers/analytics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsNotifier muscle aggregation', () {
    test('aggregates completed sets and max weight by muscle group', () {
      final sessions = [
        WorkoutSessionModel(
          id: 'session-1',
          userId: 'user-1',
          routineId: 'routine-1',
          routineName: 'Push',
          startTime: DateTime(2026, 6, 1),
          endTime: DateTime(2026, 6, 1, 1),
          durationSeconds: 3600,
          totalWeightKg: 220,
          completedSetsPercentage: 100,
          exercises: [
            ExerciseSessionModel(
              workoutId: 'bench_press',
              title: 'Bench Press',
              sets: [
                SetSessionModel(reps: 10, weight: 20, isCompleted: true),
                SetSessionModel(reps: 10, weight: 20, isCompleted: true),
                SetSessionModel(reps: 8, weight: 10, isCompleted: false),
              ],
            ),
          ],
        ),
        WorkoutSessionModel(
          id: 'session-2',
          userId: 'user-1',
          routineId: 'routine-2',
          routineName: 'Legs',
          startTime: DateTime(2026, 6, 2),
          endTime: DateTime(2026, 6, 2, 1),
          durationSeconds: 3600,
          totalWeightKg: 300,
          completedSetsPercentage: 100,
          exercises: [
            ExerciseSessionModel(
              workoutId: 'squats',
              title: 'Back Squat',
              sets: [
                SetSessionModel(reps: 10, weight: 25, isCompleted: true),
                SetSessionModel(reps: 8, weight: 30, isCompleted: true),
              ],
            ),
          ],
        ),
      ];

      final exerciseMuscleMap = {'bench_press': 'chest', 'squats': 'quadriceps'};

      final stats = AnalyticsNotifier.aggregateMuscleStats(sessions, exerciseMuscleMap);

      expect(stats['chest']?.totalSets, 2);
      expect(stats['chest']?.totalReps, 20);
      expect(stats['chest']?.totalVolume, 400);
      expect(stats['chest']?.maxWeight, 20);
      expect(stats['quadriceps']?.totalSets, 2);
      expect(stats['quadriceps']?.totalReps, 18);
      expect(stats['quadriceps']?.totalVolume, 430);
      expect(stats['quadriceps']?.maxWeight, 30);
      expect(stats['chest']?.topExercises, contains('Bench Press'));
    });
  });
}
