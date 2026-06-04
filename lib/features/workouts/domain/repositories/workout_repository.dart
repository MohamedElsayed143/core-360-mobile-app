import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';

abstract class WorkoutRepository {
  Future<List<Exercise>> getGlobalWorkouts();
  Future<List<Routine>> getUserRoutines(String userId);
  Future<void> saveRoutine(Routine routine);
  Future<void> deleteRoutine(String routineId);
  Future<String> createSharedRoutine(Routine routine, {DateTime? expiresAt});
  Future<Routine?> getSharedRoutineByCode(String code);
}
