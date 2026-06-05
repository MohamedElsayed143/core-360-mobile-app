import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_client.dart';
import '../../../../core/network/api_client.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../domain/entities/routine.dart';
import '../../../workouts/data/models/workout_session_model.dart';

// ─── TIMER STATE ────────────────────────────────────────────────────────────

class WorkoutTimerState {
  final int elapsedSeconds;
  final bool isRunning;

  const WorkoutTimerState({this.elapsedSeconds = 0, this.isRunning = false});

  String get formatted {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  WorkoutTimerState copyWith({int? elapsedSeconds, bool? isRunning}) {
    return WorkoutTimerState(
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class WorkoutTimerNotifier extends Notifier<WorkoutTimerState> {
  Timer? _ticker;

  @override
  WorkoutTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const WorkoutTimerState();
  }

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resume() => start();

  void reset() {
    _ticker?.cancel();
    state = const WorkoutTimerState();
  }
}

final workoutTimerProvider =
    NotifierProvider<WorkoutTimerNotifier, WorkoutTimerState>(
      WorkoutTimerNotifier.new,
    );

// ─── ACTIVE SET ROW STATE ────────────────────────────────────────────────────

class ActiveSetRow {
  final double weight;
  final int reps;
  final bool isCompleted;

  const ActiveSetRow({
    this.weight = 0.0,
    this.reps = 10,
    this.isCompleted = false,
  });

  ActiveSetRow copyWith({double? weight, int? reps, bool? isCompleted}) {
    return ActiveSetRow(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// ─── ACTIVE EXERCISE STATE ────────────────────────────────────────────────────

class ActiveExerciseState {
  final String workoutId;
  final String title;
  final String targetMuscle;
  final String videoUrl;
  final String gifUrl;
  final List<ActiveSetRow> sets;

  const ActiveExerciseState({
    required this.workoutId,
    required this.title,
    required this.targetMuscle,
    required this.videoUrl,
    required this.gifUrl,
    required this.sets,
  });

  ActiveExerciseState copyWith({List<ActiveSetRow>? sets}) {
    return ActiveExerciseState(
      workoutId: workoutId,
      title: title,
      targetMuscle: targetMuscle,
      videoUrl: videoUrl,
      gifUrl: gifUrl,
      sets: sets ?? this.sets,
    );
  }
}

// ─── ACTIVE WORKOUT STATE ─────────────────────────────────────────────────────

class ActiveWorkoutState {
  final Routine? routine;
  final List<ActiveExerciseState> exercises;
  final int activeIndex;
  final bool isSaving;
  final bool isFinished;
  final String? errorMessage;
  final DateTime startTime;

  const ActiveWorkoutState({
    this.routine,
    this.exercises = const [],
    this.activeIndex = 0,
    this.isSaving = false,
    this.isFinished = false,
    this.errorMessage,
    required this.startTime,
  });

  ActiveExerciseState? get activeExercise =>
      exercises.isNotEmpty && activeIndex < exercises.length
          ? exercises[activeIndex]
          : null;

  bool get hasNext => activeIndex < exercises.length - 1;
  bool get hasPrev => activeIndex > 0;

  // Computed summary metrics
  int get totalSets => exercises.fold(0, (acc, e) => acc + e.sets.length);

  int get completedSets => exercises.fold(
    0,
    (acc, e) => acc + e.sets.where((s) => s.isCompleted).length,
  );

  double get completedPercentage =>
      totalSets == 0 ? 0.0 : (completedSets / totalSets) * 100;

  double get totalWeightKg => exercises.fold(
    0.0,
    (acc, e) =>
        acc +
        e.sets
            .where((s) => s.isCompleted)
            .fold(0.0, (setSum, s) => setSum + (s.weight * s.reps)),
  );

  ActiveWorkoutState copyWith({
    Routine? routine,
    List<ActiveExerciseState>? exercises,
    int? activeIndex,
    bool? isSaving,
    bool? isFinished,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return ActiveWorkoutState(
      routine: routine ?? this.routine,
      exercises: exercises ?? this.exercises,
      activeIndex: activeIndex ?? this.activeIndex,
      isSaving: isSaving ?? this.isSaving,
      isFinished: isFinished ?? this.isFinished,
      errorMessage: errorMessage,
      startTime: startTime ?? this.startTime,
    );
  }
}

// ─── ACTIVE WORKOUT NOTIFIER ──────────────────────────────────────────────────

class ActiveWorkoutNotifier extends Notifier<ActiveWorkoutState> {
  @override
  ActiveWorkoutState build() {
    return ActiveWorkoutState(startTime: DateTime.now());
  }

  String _getYoutubeGifUrl(String videoUrl) {
    if (videoUrl.isEmpty) return '';
    try {
      final uri = Uri.tryParse(videoUrl);
      if (uri == null) return '';

      String? videoId;
      if (videoUrl.contains('youtu.be/')) {
        videoId = videoUrl.split('youtu.be/').last.split('?').first;
      } else if (videoUrl.contains('v=')) {
        videoId = uri.queryParameters['v'];
      } else if (videoUrl.contains('shorts/')) {
        videoId = videoUrl.split('shorts/').last.split('?').first;
      } else if (videoUrl.contains('embed/')) {
        videoId = videoUrl.split('embed/').last.split('?').first;
      }

      if (videoId != null && videoId.isNotEmpty) {
        return 'https://i.ytimg.com/an_webp/$videoId/mqdefault_6s.webp';
      }
    } catch (_) {}
    return '';
  }

  String _generateIdForTitle(String title, int index) {
    final lower = title.toLowerCase().trim();
    if (lower == 'barbell bench press') return 'bench_press_001';
    if (lower == 'push-ups' || lower == 'push-up' || lower == 'push up') return 'push_ups_002';
    if (lower == 'barbell back squat' || lower == 'squat' || lower == 'bodyweight squat') return 'squats_003';
    if (lower == 'pull-ups' || lower == 'pull-up' || lower == 'pull up') return 'pull_ups_004';
    if (lower == 'plank' || lower == 'forearm plank') return 'plank_005';
    if (lower == 'barbell curl' || lower == 'dumbbell bicep curl') return 'bicep_curl_006';
    if (lower == 'tricep rope pushdown' || lower == 'overhead dumbbell tricep extension') return 'tricep_extension_007';
    if (lower == 'overhead press' || lower == 'dumbbell overhead shoulder press') return 'overhead_press_008';
    if (lower == 'romanian deadlift') return 'romanian_deadlift_009';
    if (lower == 'calf raises' || lower == 'standing calf raise') return 'calve_raises_010';
    if (lower == 'lateral raises' || lower == 'dumbbell lateral raise') return 'lateral_raises_011';
    if (lower == 'hanging leg raise') return 'leg_raises_012';

    return '${lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${index.toString().padLeft(3, '0')}';
  }

  /// Initialises session from a saved Routine with pre-populated exercise data.
  /// Loads media URLs from local workouts.json, with YouTube WebP and ApiClient fallbacks.
  Future<void> initSession(Routine routine, [List<Map<String, String>>? videoUrlMap]) async {
    List<dynamic> jsonList = [];
    try {
      final String jsonContent = await rootBundle.loadString('assets/workouts.json');
      jsonList = json.decode(jsonContent) as List<dynamic>;
    } catch (e) {
      debugPrint('Error loading workouts.json in initSession: $e');
    }

    final exercises = routine.exercises.map((ex) {
      Map<String, dynamic>? matchedEx;
      final exTitleClean = ex.title.toLowerCase().trim();
      final exWorkoutIdClean = ex.workoutId.toLowerCase().trim();

      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        if (item is Map<String, dynamic>) {
          final itemTitle = (item['title'] as String?)?.toLowerCase().trim() ?? '';
          final itemJsonId = (item['id'] as String?)?.toLowerCase().trim() ?? '';
          final itemJsonWorkoutId = (item['workoutId'] as String?)?.toLowerCase().trim() ?? '';
          final generatedId = _generateIdForTitle(itemTitle, i);

          if (itemJsonId == exWorkoutIdClean ||
              itemJsonWorkoutId == exWorkoutIdClean ||
              generatedId == exWorkoutIdClean ||
              itemTitle == exTitleClean) {
            matchedEx = item;
            break;
          }
        }
      }

      String videoUrl = matchedEx?['videoUrl'] as String? ?? '';

      // If no video URL found in JSON, try external videoUrlMap (from caller), then ApiClient fallback
      if (videoUrl.isEmpty && videoUrlMap != null) {
        videoUrl = videoUrlMap
                .firstWhere(
                  (m) => m['workoutId'] == ex.workoutId,
                  orElse: () => {'videoUrl': ''},
                )['videoUrl'] ??
            '';
      }
      if (videoUrl.isEmpty) {
        videoUrl = ApiClient.resolveWorkoutVideoUrl(ex.title);
      }

      String gifUrl = matchedEx?['gifUrl'] as String? ?? '';

      // Fall back to the dynamic YouTube WebP converter stream preview
      if (gifUrl.isEmpty) {
        gifUrl = _getYoutubeGifUrl(videoUrl);
      }

      // If still no gifUrl, fall back to GitHub image DB
      if (gifUrl.isEmpty && matchedEx != null) {
        final formattedName = ex.title
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');
        gifUrl =
            'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$formattedName/images/0.gif';
      }

      final sets = ex.sets.isNotEmpty
          ? ex.sets
              .map((s) => ActiveSetRow(weight: s.weight, reps: s.reps))
              .toList()
          : [const ActiveSetRow()];

      return ActiveExerciseState(
        workoutId: ex.workoutId,
        title: ex.title,
        targetMuscle: ex.targetMuscle,
        videoUrl: videoUrl,
        gifUrl: gifUrl,
        sets: sets,
      );
    }).toList();

    state = ActiveWorkoutState(
      routine: routine,
      exercises: exercises,
      activeIndex: 0,
      startTime: DateTime.now(),
    );

    ref.read(workoutTimerProvider.notifier).start();
  }

  void nextExercise() {
    if (state.hasNext) {
      state = state.copyWith(activeIndex: state.activeIndex + 1);
    }
  }

  void previousExercise() {
    if (state.hasPrev) {
      state = state.copyWith(activeIndex: state.activeIndex - 1);
    }
  }

  void updateWeight(int exIndex, int setIndex, double value) {
    final updated = _updateSet(
      exIndex,
      setIndex,
      (s) => s.copyWith(weight: value),
    );
    if (updated != null) state = state.copyWith(exercises: updated);
  }

  void updateReps(int exIndex, int setIndex, int value) {
    final updated = _updateSet(
      exIndex,
      setIndex,
      (s) => s.copyWith(reps: value),
    );
    if (updated != null) state = state.copyWith(exercises: updated);
  }

  void toggleSetCompleted(int exIndex, int setIndex) {
    final updated = _updateSet(
      exIndex,
      setIndex,
      (s) => s.copyWith(isCompleted: !s.isCompleted),
    );
    if (updated != null) state = state.copyWith(exercises: updated);
  }

  void addSet(int exIndex) {
    if (exIndex >= state.exercises.length) return;
    final ex = state.exercises[exIndex];
    final lastSet = ex.sets.isNotEmpty ? ex.sets.last : const ActiveSetRow();
    final newSets = [
      ...ex.sets,
      ActiveSetRow(weight: lastSet.weight, reps: lastSet.reps),
    ];
    final updatedEx = ex.copyWith(sets: newSets);
    final updatedExercises = List<ActiveExerciseState>.from(state.exercises);
    updatedExercises[exIndex] = updatedEx;
    state = state.copyWith(exercises: updatedExercises);
  }

  void deleteSet(int exIndex, int setIndex) {
    if (exIndex >= state.exercises.length) return;
    final ex = state.exercises[exIndex];
    if (ex.sets.length <= 1) return; // keep at least 1 set
    final newSets = List<ActiveSetRow>.from(ex.sets)..removeAt(setIndex);
    final updatedExercises = List<ActiveExerciseState>.from(state.exercises);
    updatedExercises[exIndex] = ex.copyWith(sets: newSets);
    state = state.copyWith(exercises: updatedExercises);
  }

  List<ActiveExerciseState>? _updateSet(
    int exIndex,
    int setIndex,
    ActiveSetRow Function(ActiveSetRow) transform,
  ) {
    if (exIndex >= state.exercises.length) return null;
    final ex = state.exercises[exIndex];
    if (setIndex >= ex.sets.length) return null;
    final updatedSets = List<ActiveSetRow>.from(ex.sets);
    updatedSets[setIndex] = transform(updatedSets[setIndex]);
    final updatedExercises = List<ActiveExerciseState>.from(state.exercises);
    updatedExercises[exIndex] = ex.copyWith(sets: updatedSets);
    return updatedExercises;
  }

  Future<void> saveSession() async {
    final routine = state.routine;
    if (routine == null) return;

    final auth = ref.read(authProvider);
    if (auth is! AuthenticatedWithProfile) return;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final timerState = ref.read(workoutTimerProvider);
      ref.read(workoutTimerProvider.notifier).pause();

      final endTime = DateTime.now();
      final sessionId = FirebaseFirestore.instance.collection('sessions').doc().id;

      final exercises = state.exercises.map((ex) {
        return ExerciseSessionModel(
          workoutId: ex.workoutId,
          title: ex.title,
          sets: ex.sets
              .map(
                (s) => SetSessionModel(
                  reps: s.reps,
                  weight: s.weight,
                  isCompleted: s.isCompleted,
                ),
              )
              .toList(),
        );
      }).toList();

      final sessionModel = WorkoutSessionModel(
        id: sessionId,
        userId: auth.user.uid,
        routineId: routine.id,
        routineName: routine.name,
        startTime: state.startTime,
        endTime: endTime,
        durationSeconds: timerState.elapsedSeconds,
        totalWeightKg: state.totalWeightKg,
        completedSetsPercentage: state.completedPercentage,
        exercises: exercises,
      );

      final client = ref.read(firebaseClientProvider);
      await client.sessionsCollection.doc(sessionId).set(sessionModel.toMap());

      state = state.copyWith(isSaving: false, isFinished: true);
    } catch (e) {
      debugPrint('Error saving session: $e');
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save session: $e',
      );
    }
  }

  void reset() {
    ref.read(workoutTimerProvider.notifier).reset();
    state = ActiveWorkoutState(startTime: DateTime.now());
  }
}

final activeWorkoutProvider =
    NotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>(
      ActiveWorkoutNotifier.new,
    );
