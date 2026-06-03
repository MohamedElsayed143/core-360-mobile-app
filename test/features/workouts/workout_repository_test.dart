import 'package:flutter_test/flutter_test.dart';
import 'package:core_360_app/features/workouts/domain/entities/exercise.dart';
import 'package:core_360_app/features/workouts/domain/entities/routine.dart';
import 'package:core_360_app/features/workouts/domain/entities/routine_exercise.dart';
import 'package:core_360_app/features/workouts/domain/entities/set_config.dart';
import 'package:core_360_app/features/workouts/domain/repositories/workout_repository.dart';

class MockWorkoutRepository implements WorkoutRepository {
  final Map<String, Routine> _userRoutines = {};
  final Map<String, Routine> _sharedRoutines = {};
  final List<Exercise> _globalWorkouts = [
    Exercise(
      id: 'bench_press_001',
      title: 'Barbell Bench Press',
      description: 'A classic upper-body strength exercise.',
      targetMuscle: 'chest',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: false,
    ),
    Exercise(
      id: 'squats_003',
      title: 'Bodyweight Squat',
      description: 'A fundamental lower body movement.',
      targetMuscle: 'quadriceps',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: true,
    ),
  ];

  @override
  Future<List<Exercise>> getGlobalWorkouts() async {
    return _globalWorkouts;
  }

  @override
  Future<List<Routine>> getUserRoutines(String userId) async {
    return _userRoutines.values.where((r) => r.userId == userId).toList();
  }

  @override
  Future<void> saveRoutine(Routine routine) async {
    final id = routine.id.isEmpty ? 'mock-routine-${_userRoutines.length + 1}' : routine.id;
    final savedRoutine = routine.copyWith(id: id);
    _userRoutines[id] = savedRoutine;
  }

  @override
  Future<void> deleteRoutine(String routineId) async {
    _userRoutines.remove(routineId);
  }

  @override
  Future<String> createSharedRoutine(Routine routine, {DateTime? expiresAt}) async {
    final code = 'COREABCD';
    _sharedRoutines[code] = routine.copyWith(shareCode: code);
    return code;
  }

  @override
  Future<Routine?> getSharedRoutineByCode(String code) async {
    return _sharedRoutines[code.toUpperCase()];
  }
}

void main() {
  group('WorkoutRepository Unit Tests', () {
    late WorkoutRepository repository;

    setUp(() {
      repository = MockWorkoutRepository();
    });

    test('getGlobalWorkouts returns seeded list of exercises', () async {
      final workouts = await repository.getGlobalWorkouts();
      expect(workouts.length, equals(2));
      expect(workouts.first.id, equals('bench_press_001'));
      expect(workouts.first.title, equals('Barbell Bench Press'));
    });

    test('saveRoutine and getUserRoutines saves and retrieves routines correctly', () async {
      final routine = Routine(
        id: '',
        userId: 'user-123',
        name: 'POWER TEST SPLIT',
        exercises: [
          RoutineExercise(
            workoutId: 'squats_003',
            title: 'Bodyweight Squat',
            targetMuscle: 'quadriceps',
            sets: [SetConfig(reps: 12, weight: 0.0)],
            order: 0,
          )
        ],
      );

      await repository.saveRoutine(routine);

      final routines = await repository.getUserRoutines('user-123');
      expect(routines.length, equals(1));
      expect(routines.first.name, equals('POWER TEST SPLIT'));
      expect(routines.first.exercises.length, equals(1));
      expect(routines.first.exercises.first.workoutId, equals('squats_003'));
    });

    test('deleteRoutine removes the routine from user library', () async {
      final routine = Routine(
        id: 'routine-to-delete',
        userId: 'user-123',
        name: 'TEMPORARY ROUTINE',
        exercises: [],
      );

      await repository.saveRoutine(routine);
      var routines = await repository.getUserRoutines('user-123');
      expect(routines.length, equals(1));

      await repository.deleteRoutine('routine-to-delete');
      routines = await repository.getUserRoutines('user-123');
      expect(routines.isEmpty, isTrue);
    });

    test('createSharedRoutine and getSharedRoutineByCode works correctly', () async {
      final routine = Routine(
        id: 'my-routine-123',
        userId: 'user-123',
        name: 'SHARED SPLIT',
        exercises: [
          RoutineExercise(
            workoutId: 'bench_press_001',
            title: 'Barbell Bench Press',
            targetMuscle: 'chest',
            sets: [SetConfig(reps: 8, weight: 60.0)],
            order: 0,
          ),
        ],
      );

      final code = await repository.createSharedRoutine(routine);
      expect(code, startsWith('CORE'));
      expect(code.length, equals(8));

      final shared = await repository.getSharedRoutineByCode(code);
      expect(shared, isNotNull);
      expect(shared!.name, equals('SHARED SPLIT'));
      expect(shared.exercises.first.workoutId, equals('bench_press_001'));
      expect(shared.exercises.first.sets.first.weight, equals(60.0));
    });
  });
}
