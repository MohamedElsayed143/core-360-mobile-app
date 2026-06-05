import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/network/api_client.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../data/models/ai_workout_models.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../domain/entities/routine_exercise.dart';
import '../../domain/entities/set_config.dart';
import 'workout_provider.dart';

class AiPlannerState {
  final int step; // 0 to 3
  final String experienceLevel; // 'beginner', 'intermediate', 'advanced'
  final int trainingFrequency; // 2 to 6
  final String splitFocus; // 'full_body', 'upper', 'lower', 'push', 'pull', 'core'
  final bool isGenerating;
  final String? errorMessage;
  final Routine? generatedRoutine;

  AiPlannerState({
    this.step = 0,
    this.experienceLevel = 'beginner',
    this.trainingFrequency = 3,
    this.splitFocus = 'full_body',
    this.isGenerating = false,
    this.errorMessage,
    this.generatedRoutine,
  });

  AiPlannerState copyWith({
    int? step,
    String? experienceLevel,
    int? trainingFrequency,
    String? splitFocus,
    bool? isGenerating,
    String? errorMessage,
    Routine? generatedRoutine,
  }) {
    return AiPlannerState(
      step: step ?? this.step,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      trainingFrequency: trainingFrequency ?? this.trainingFrequency,
      splitFocus: splitFocus ?? this.splitFocus,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
      generatedRoutine: generatedRoutine ?? this.generatedRoutine,
    );
  }
}

class AiPlannerNotifier extends Notifier<AiPlannerState> {
  @override
  AiPlannerState build() {
    return AiPlannerState();
  }

  void setStep(int step) {
    state = state.copyWith(step: step);
  }

  void setExperienceLevel(String level) {
    state = state.copyWith(experienceLevel: level);
  }

  void setTrainingFrequency(int frequency) {
    state = state.copyWith(trainingFrequency: frequency);
  }

  void setSplitFocus(String focus) {
    state = state.copyWith(splitFocus: focus);
  }

  void reset() {
    state = AiPlannerState();
  }

  String _mapSplitFocus(String focus) {
    switch (focus) {
      case 'full_body':
        return 'Full Body';
      case 'upper':
        return 'Upper Body';
      case 'lower':
        return 'Lower Body';
      case 'push':
        return 'Push Split';
      case 'pull':
        return 'Pull Split';
      case 'core':
        return 'Core & Cardio';
      default:
        return focus;
    }
  }

  String _capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

  int _parseReps(String repsStr) {
    final match = RegExp(r'\d+').firstMatch(repsStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 10;
    }
    return 10;
  }

  double _parseWeight(String weightStr) {
    final lower = weightStr.toLowerCase();
    if (lower.contains('bodyweight') || lower.contains('body')) {
      return 0.0;
    }
    final match = RegExp(r'[\d.]+').firstMatch(weightStr);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }
    return 0.0;
  }

  Future<Routine?> generateAiRoutine() async {
    final auth = ref.read(authProvider);
    String uid;
    String goals = 'Muscle Gain, Core Strength';
    String experience = _capitalize(state.experienceLevel);
    String frequency = '${state.trainingFrequency} Days';
    String focus = _mapSplitFocus(state.splitFocus);
    String injuries = 'None';

    if (auth is AuthenticatedWithProfile) {
      uid = auth.user.uid;
      goals = auth.profile.goals.join(', ');
      injuries = auth.profile.injuries ?? 'None';
    } else if (auth is AuthenticatedWithoutProfile) {
      uid = auth.user.uid;
    } else {
      // Direct Firebase Auth checkout fallback
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        uid = currentUser.uid;
      } else {
        state = state.copyWith(
          isGenerating: false,
          errorMessage: "Authentication failed. Please sign in.",
        );
        return null;
      }
    }

    // Fetch global seeded workouts
    final globalWorkoutsAsync = ref.read(globalWorkoutsProvider);
    final globalWorkouts = globalWorkoutsAsync.value ?? [];

    state = state.copyWith(isGenerating: true, errorMessage: null, generatedRoutine: null);

    try {
      final apiClient = ref.read(apiClientProvider);

      // Map survey configuration to the API payload
      final request = AiWorkoutRequest(
        goal: goals,
        experience: experience,
        frequency: frequency,
        focus: focus,
        injuries: injuries,
        availableExercises: globalWorkouts.map((w) => w.title).toList(),
      );

      // Perform API call to local/hosted Next.js backend
      final apiResponse = await apiClient.generateAiWorkout(request);
      final routineData = apiResponse.routine;

      final List<RoutineExercise> exercises = [];
      for (int i = 0; i < routineData.exercises.length; i++) {
        final apiEx = routineData.exercises[i];

        Exercise matchedExercise;
        try {
          matchedExercise = globalWorkouts.firstWhere(
            (w) => w.title.toLowerCase().trim() == apiEx.name.toLowerCase().trim(),
          );
        } catch (_) {
          try {
            matchedExercise = globalWorkouts.firstWhere(
              (w) => w.title.toLowerCase().contains(apiEx.name.toLowerCase()) ||
                     apiEx.name.toLowerCase().contains(w.title.toLowerCase()),
            );
          } catch (_) {
            final resolvedVideoUrl = await apiClient.getWorkoutVideoUrl(apiEx.name);
            final resolvedGifUrl = await apiClient.getWorkoutGifUrl(apiEx.name);
            matchedExercise = Exercise(
              id: 'dynamic_${apiEx.name.toLowerCase().replaceAll(' ', '_')}',
              title: apiEx.name,
              description: apiEx.notes,
              targetMuscle: state.splitFocus == 'lower' ? 'legs' : 'chest',
              thumbnailUrl: '',
              videoUrl: resolvedVideoUrl,
              gifUrl: resolvedGifUrl,
              aiSupported: false,
            );
          }
        }

        // Safely parse reps and weight strings into Config List
        final parsedReps = _parseReps(apiEx.reps);
        final parsedWeight = _parseWeight(apiEx.weightKg);

        final setsList = List.generate(
          apiEx.sets > 0 ? apiEx.sets : 3,
          (_) => SetConfig(reps: parsedReps, weight: parsedWeight),
        );

        exercises.add(
          RoutineExercise(
            workoutId: matchedExercise.id,
            title: matchedExercise.title,
            targetMuscle: matchedExercise.targetMuscle,
            sets: setsList,
            order: i,
          ),
        );
      }

      final generatedRoutine = Routine(
        id: '',
        userId: uid,
        name: routineData.routineName,
        exercises: exercises,
        isAiGenerated: true,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        isGenerating: false,
        generatedRoutine: generatedRoutine,
      );

      return generatedRoutine;
    } catch (e, stack) {
      debugPrint('Error generating routine: $e\n$stack');
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'Failed to generate AI routine from Next.js server: $e',
      );
      return null;
    }
  }

  Future<void> saveGeneratedRoutine() async {
    final routine = state.generatedRoutine;
    if (routine == null) return;
    
    try {
      await ref.read(userRoutinesProvider.notifier).saveRoutine(routine);
      state = state.copyWith(generatedRoutine: null);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to save generated routine: $e');
      rethrow;
    }
  }
}

final aiPlannerProvider = NotifierProvider<AiPlannerNotifier, AiPlannerState>(() {
  return AiPlannerNotifier();
});
