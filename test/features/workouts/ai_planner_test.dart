import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:core_360_app/core/network/api_client.dart';
import 'package:core_360_app/features/onboarding/domain/entities/user_profile.dart';
import 'package:core_360_app/features/onboarding/presentation/providers/auth_provider.dart';
import 'package:core_360_app/features/workouts/domain/entities/exercise.dart';
import 'package:core_360_app/features/workouts/domain/entities/routine.dart';
import 'package:core_360_app/features/workouts/domain/repositories/workout_repository.dart';
import 'package:core_360_app/features/workouts/data/repositories/workout_repository_impl.dart';
import 'package:core_360_app/features/workouts/presentation/providers/ai_planner_provider.dart';
import 'package:core_360_app/features/workouts/presentation/providers/workout_provider.dart';

// Simple fakes for auth mocking
class FakeUser extends Fake implements fb.User {
  @override
  String get uid => 'user-uid-abc-123';
}

class MockAuthNotifier extends AuthNotifier {
  final fb.User _user;
  final UserProfile _profile;

  MockAuthNotifier(this._user, this._profile);

  @override
  AuthState build() {
    return AuthenticatedWithProfile(_user, _profile);
  }
}

class MockWorkoutRepository implements WorkoutRepository {
  final List<Exercise> _globalWorkouts = [
    Exercise(
      id: 'bench_press_001',
      title: 'Barbell Bench Press',
      description: 'Targets chest, shoulders, triceps.',
      targetMuscle: 'chest',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: false,
    ),
    Exercise(
      id: 'push_ups_002',
      title: 'Push-Up',
      description: 'Targets chest, triceps, core.',
      targetMuscle: 'chest',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: true,
    ),
    Exercise(
      id: 'squats_003',
      title: 'Bodyweight Squat',
      description: 'Targets quadriceps, glutes.',
      targetMuscle: 'quadriceps',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: true,
    ),
    Exercise(
      id: 'romanian_deadlift_009',
      title: 'Romanian Deadlift',
      description: 'Targets hamstrings, glutes.',
      targetMuscle: 'hamstring',
      thumbnailUrl: '',
      videoUrl: '',
      aiSupported: false,
    ),
  ];

  @override
  Future<List<Exercise>> getGlobalWorkouts() async => _globalWorkouts;

  @override
  Future<List<Routine>> getUserRoutines(String userId) async => [];

  @override
  Future<void> saveRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine(String routineId) async {}

  @override
  Future<String> createSharedRoutine(Routine routine, {DateTime? expiresAt}) async => '';

  @override
  Future<Routine?> getSharedRoutineByCode(String code) async => null;
}

void main() {
  group('AI Workout Planner Survey & Groq Generation Unit Tests', () {
    late ProviderContainer container;
    late UserProfile userProfile;
    late fb.User mockUser;

    setUp(() {
      mockUser = FakeUser();
      userProfile = UserProfile(
        age: 28,
        height: 180.0,
        weight: 75.0,
        goals: ['Muscle Gain'],
        injuries: 'Lower back injury',
      );

      container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(mockUser, userProfile)),
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          apiClientProvider.overrideWithValue(ApiClient()), // Standard ApiClient runs local simulation when key is empty
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('AiPlannerNotifier manages wizard steps and survey inputs correctly', () {
      final notifier = container.read(aiPlannerProvider.notifier);
      
      // Check initial state
      var state = container.read(aiPlannerProvider);
      expect(state.step, equals(0));
      expect(state.experienceLevel, equals('beginner'));
      expect(state.trainingFrequency, equals(3));
      expect(state.splitFocus, equals('full_body'));

      // Modify values
      notifier.setStep(2);
      notifier.setExperienceLevel('advanced');
      notifier.setTrainingFrequency(5);
      notifier.setSplitFocus('lower');

      state = container.read(aiPlannerProvider);
      expect(state.step, equals(2));
      expect(state.experienceLevel, equals('advanced'));
      expect(state.trainingFrequency, equals(5));
      expect(state.splitFocus, equals('lower'));

      // Reset
      notifier.reset();
      state = container.read(aiPlannerProvider);
      expect(state.step, equals(0));
    });

    test('generateAiRoutine runs Groq API local simulation with injury safeguards', () async {
      // First, seed global workouts list inside the provider state
      await container.read(globalWorkoutsProvider.future);

      final notifier = container.read(aiPlannerProvider.notifier);
      notifier.setExperienceLevel('intermediate');
      notifier.setTrainingFrequency(4);
      
      // Let's set a Lower Body focus
      // Since user has a 'Lower back injury', Romanian Deadlift (romanian_deadlift_009) must be filtered out
      // based on system instructions or our simulation code checks.
      notifier.setSplitFocus('lower');

      final routine = await notifier.generateAiRoutine();
      
      expect(routine, isNotNull);
      expect(routine!.name, isNotEmpty);
      expect(routine.isAiGenerated, isTrue);
      expect(routine.exercises, isNotEmpty);

      // Verify that Romanian Deadlift is filtered out
      final hasRdl = routine.exercises.any((ex) => ex.workoutId == 'romanian_deadlift_009');
      expect(hasRdl, isFalse, reason: 'Exercise that stresses lower back injury should be filtered out.');

      // Verify squats are included since squats target quadriceps and knee is not injured
      final hasSquats = routine.exercises.any((ex) => ex.workoutId == 'squats_003');
      expect(hasSquats, isTrue);
    });

    test('generateAiRoutine filters exercises targeting shoulders on Upper Split if user has shoulder injury', () async {
      // Create new container with shoulder injury profile
      final shoulderInjuryProfile = UserProfile(
        age: 32,
        height: 175.0,
        weight: 80.0,
        goals: ['Endurance'],
        injuries: 'Shoulder impingement',
      );

      final shoulderContainer = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(mockUser, shoulderInjuryProfile)),
          workoutRepositoryProvider.overrideWithValue(MockWorkoutRepository()),
          apiClientProvider.overrideWithValue(ApiClient()),
        ],
      );

      await shoulderContainer.read(globalWorkoutsProvider.future);

      final notifier = shoulderContainer.read(aiPlannerProvider.notifier);
      notifier.setSplitFocus('upper');

      final routine = await notifier.generateAiRoutine();
      expect(routine, isNotNull);

      // Verify that bench press (bench_press_001) is filtered out because user reports shoulder pain
      final hasBench = routine!.exercises.any((ex) => ex.workoutId == 'bench_press_001');
      expect(hasBench, isFalse, reason: 'Shoulder intensive exercises must be filtered out.');

      shoulderContainer.dispose();
    });
  });
}
