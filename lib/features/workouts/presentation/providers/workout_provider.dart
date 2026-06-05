import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';

/// Provider to load global seeded exercises from Firestore
final globalWorkoutsProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return await repo.getGlobalWorkouts();
});

/// StateNotifier handling the user's saved routines
class UserRoutinesNotifier extends Notifier<AsyncValue<List<Routine>>> {
  @override
  AsyncValue<List<Routine>> build() {
    Future.microtask(() => _loadRoutines());
    return const AsyncValue.loading();
  }

  String? get _userId {
    final authState = ref.watch(authProvider);
    if (authState is AuthenticatedWithProfile) {
      return authState.user.uid;
    }
    return null;
  }

  Future<void> _loadRoutines() async {
    final uid = _userId;
    if (uid == null) {
      state = const AsyncValue.data([]);
      return;
    }
    
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final routines = await repo.getUserRoutines(uid);
      state = AsyncValue.data(routines);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await _loadRoutines();
  }

  Future<void> saveRoutine(Routine routine) async {
    final uid = _userId;
    if (uid == null) throw Exception("User must be logged in to save routines.");
    
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final routineWithUser = routine.copyWith(userId: uid);
      await repo.saveRoutine(routineWithUser);
      await _loadRoutines();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteRoutine(String routineId) async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.deleteRoutine(routineId);
      await _loadRoutines();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }
}

/// Provider for list of user routines
final userRoutinesProvider = NotifierProvider<UserRoutinesNotifier, AsyncValue<List<Routine>>>(() {
  return UserRoutinesNotifier();
});
