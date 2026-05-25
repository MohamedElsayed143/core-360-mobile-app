import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
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

  Future<Routine?> generateAiRoutine() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthenticatedWithProfile) {
      state = state.copyWith(errorMessage: "User profile not loaded. Authenticate again.");
      return null;
    }

    final user = auth.user;
    final profile = auth.profile;
    
    // Fetch global seeded workouts
    final globalWorkoutsAsync = ref.read(globalWorkoutsProvider);
    final globalWorkouts = globalWorkoutsAsync.value ?? [];

    state = state.copyWith(isGenerating: true, errorMessage: null, generatedRoutine: null);

    try {
      final apiClient = ref.read(apiClientProvider);

      // Construct workouts summary for the LLM
      final workoutSummaryBuffer = StringBuffer();
      for (final w in globalWorkouts) {
        workoutSummaryBuffer.writeln(
          "- ID: ${w.id}, Title: ${w.title}, Target Muscle: ${w.targetMuscle}, Description: ${w.description}"
        );
      }

      final systemPrompt = '''
You are a highly professional, expert AI personal trainer and biomechanical safety coordinator for the "Core-360" fitness application.
Your objective is to compile a highly customized, safe, and effective workout routine tailored to the user's biometrics, experience, split focus, and injury restrictions.

Strict Safety Rules:
1. You MUST check the user's "Pre-Existing Injuries". If they have specified any injury (e.g. lower back pain, shoulder pain, knee issues), you MUST NOT prescribe any exercise that targets, stresses, or loads that joint or muscle group.
2. Select exercises ONLY from the provided global library of available workouts. Do NOT invent new workout IDs or titles.
3. Calculate sets, reps, and default weight in kilograms (kg) based on their body weight, goals, and experience level:
   - For bodyweight exercises (e.g. Squat squats_003, Push-Up push_ups_002, Plank plank_005, Pull-Up pull_ups_004, Leg Raise leg_raises_012), the default weight (kg) MUST be 0.0.
   - For weighted barbell/dumbbell exercises (e.g. Bench Press bench_press_001, Curls bicep_curl_006, Overhead Press overhead_press_008, Romanian Deadlift romanian_deadlift_009), estimate a safe, realistic starter weight for their experience level and weight.
   - Prescribe between 3 to 5 exercises in the routine.

You must output a raw JSON object matching this schema, with no markdown code fences or extra text, just the raw JSON:
{
  "name": "A short, premium-sounding, motivational routine name (e.g., 'Obsidian Chest Sculpt' or 'Core-360 Leg Developer')",
  "exercises": [
    {
      "workoutId": "id of the exercise from the list",
      "sets": [
        {
          "reps": integer,
          "kg": double
        }
      ]
    }
  ]
}
''';

      final userPrompt = '''
User Biometrics & Profile:
- Age: ${profile.age}
- Height: ${profile.height} cm
- Weight: ${profile.weight} kg
- Fitness Goals: ${profile.goals.join(', ')}
- Pre-Existing Injuries: ${profile.injuries ?? 'None'}

Routine Parameters:
- Experience Level: ${state.experienceLevel}
- Training Frequency: ${state.trainingFrequency} days/week
- Workout Split Focus: ${state.splitFocus}

Available Workouts Library:
$workoutSummaryBuffer
''';

      final response = await apiClient.getChatCompletion(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      final choice = response['choices']?[0];
      final content = choice?['message']?['content'] as String? ?? '';
      
      // Clean content if model wrapped in markdown blocks
      var jsonStr = content.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final routineName = parsed['name'] as String? ?? 'AI Generated Workout';
      final jsonExercises = parsed['exercises'] as List? ?? [];

      final List<RoutineExercise> exercises = [];
      for (int i = 0; i < jsonExercises.length; i++) {
        final exMap = Map<String, dynamic>.from(jsonExercises[i] as Map);
        final workoutId = exMap['workoutId'] as String? ?? '';
        
        // Find corresponding exercise in globalWorkouts
        final globalWorkout = globalWorkouts.firstWhere(
          (w) => w.id == workoutId,
          orElse: () => Exercise(
            id: workoutId,
            title: exMap['title'] as String? ?? 'Exercise',
            description: '',
            targetMuscle: exMap['targetMuscle'] as String? ?? 'chest',
            thumbnailUrl: '',
            videoUrl: '',
            aiSupported: false,
          ),
        );

        final jsonSets = exMap['sets'] as List? ?? [];
        final sets = jsonSets.map((s) {
          final sMap = Map<String, dynamic>.from(s as Map);
          return SetConfig(
            reps: sMap['reps'] as int? ?? 10,
            weight: (sMap['kg'] as num? ?? 0.0).toDouble(),
          );
        }).toList();

        exercises.add(RoutineExercise(
          workoutId: globalWorkout.id,
          title: globalWorkout.title,
          targetMuscle: globalWorkout.targetMuscle,
          sets: sets,
          order: i,
        ));
      }

      final generatedRoutine = Routine(
        id: '',
        userId: user.uid,
        name: routineName,
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
      state = state.copyWith(isGenerating: false, errorMessage: 'Failed to generate AI routine: $e');
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
