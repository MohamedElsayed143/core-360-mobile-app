import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/firebase/firebase_client.dart';
import '../../../onboarding/presentation/providers/auth_provider.dart';
import '../../data/models/workout_session_model.dart';
import '../../data/models/pose_analysis_model.dart';
import 'workout_provider.dart';

// ─── ANALYTICS MODELS ────────────────────────────────────────────────────────

class MuscleStat {
  final String muscleName;
  final int totalSets;
  final int totalReps;
  final double totalVolume;
  final double maxWeight; // Highest raw weight used (not multiplied by reps)
  final List<String> topExercises;

  MuscleStat({
    required this.muscleName,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
    required this.maxWeight,
    required this.topExercises,
  });
}

class AnalyticsState {
  final int lookbackDays; // 7 or 30
  final bool isLoading;
  final String? errorMessage;
  final double totalVolume;
  final int completedSessions;
  final double averageAccuracy;
  final int totalMinutes;
  final List<MapEntry<DateTime, double>> volumeHistory; // for line chart
  final List<MapEntry<String, double>> accuracyPerExercise; // for bar chart
  final Map<String, MuscleStat> muscleStats;

  AnalyticsState({
    this.lookbackDays = 7,
    this.isLoading = false,
    this.errorMessage,
    this.totalVolume = 0.0,
    this.completedSessions = 0,
    this.averageAccuracy = 0.0,
    this.totalMinutes = 0,
    this.volumeHistory = const [],
    this.accuracyPerExercise = const [],
    this.muscleStats = const {},
  });

  AnalyticsState copyWith({
    int? lookbackDays,
    bool? isLoading,
    String? errorMessage,
    double? totalVolume,
    int? completedSessions,
    double? averageAccuracy,
    int? totalMinutes,
    List<MapEntry<DateTime, double>>? volumeHistory,
    List<MapEntry<String, double>>? accuracyPerExercise,
    Map<String, MuscleStat>? muscleStats,
  }) {
    return AnalyticsState(
      lookbackDays: lookbackDays ?? this.lookbackDays,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      totalVolume: totalVolume ?? this.totalVolume,
      completedSessions: completedSessions ?? this.completedSessions,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      volumeHistory: volumeHistory ?? this.volumeHistory,
      accuracyPerExercise: accuracyPerExercise ?? this.accuracyPerExercise,
      muscleStats: muscleStats ?? this.muscleStats,
    );
  }
}

// ─── ANALYTICS NOTIFIER ──────────────────────────────────────────────────────

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sessionsSubscription;

  @override
  AnalyticsState build() {
    ref.onDispose(() {
      _sessionsSubscription?.cancel();
    });

    final auth = ref.read(authProvider);
    if (auth is AuthenticatedWithProfile) {
      _subscribeToSessions(auth.user.uid);
    }

    Future.microtask(() => refresh());
    return AnalyticsState();
  }

  void _subscribeToSessions(String uid) {
    _sessionsSubscription?.cancel();
    final firebase = ref.read(firebaseClientProvider);

    _sessionsSubscription = firebase.sessionsCollection
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (_) {
            if (!ref.mounted) return;
            Future.microtask(() => refresh());
          },
          onError: (error) {
            debugPrint('Analytics session stream error: $error');
          },
        );
  }

  void setLookbackDays(int days) {
    state = state.copyWith(lookbackDays: days);
    refresh();
  }

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (auth is! AuthenticatedWithProfile) {
      state = state.copyWith(errorMessage: 'User profile not calibrated.');
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final firebase = ref.read(firebaseClientProvider);
      final uid = auth.user.uid;
      final lookbackDate = DateTime.now().subtract(Duration(days: state.lookbackDays));

      // 1. Fetch completed sessions & pose analysis results in parallel
      final results = await Future.wait([
        firebase.firestore.collection('sessions').where('userId', isEqualTo: uid).get(),
        firebase.firestore.collection('users').doc(uid).collection('pose_analysis_results').get(),
        ref.read(globalWorkoutsProvider.future),
      ]);

      final sessionsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final posesSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final exercisesList = results[2] as List;

      // 2. Map global exercises to quick lookup dictionary
      final exerciseMuscleMap = <String, String>{};
      for (final ex in exercisesList) {
        exerciseMuscleMap[ex.id] = ex.targetMuscle.toString().replaceAll('TargetMuscle.', '');
      }

      // 3. Map & filter session logs locally
      var sessions = sessionsSnap.docs
          .map((doc) => WorkoutSessionModel.fromFirestore(doc))
          .where((s) => s.startTime.isAfter(lookbackDate))
          .toList();

      // 4. Map & filter pose results locally
      var poses = posesSnap.docs
          .map((doc) => PoseAnalysisResultModel.fromMap(doc.data()))
          .where((p) => p.timestamp.isAfter(lookbackDate))
          .toList();

      // Inject mock data if no logs exist (for graduation evaluation demo)
      if (sessions.isEmpty) {
        sessions = _generateMockSessions(uid, state.lookbackDays);
      }
      if (poses.isEmpty) {
        poses = _generateMockPoses(state.lookbackDays);
      }

      // 5. Aggregate KPIs
      double aggregatedVolume = 0.0;
      int aggregatedDurationSec = 0;
      final Map<DateTime, double> dailyVolume = {};
      final muscleStats = aggregateMuscleStats(sessions, exerciseMuscleMap);

      for (final session in sessions) {
        aggregatedDurationSec += session.durationSeconds;

        double sessionVolume = 0.0;
        for (final exercise in session.exercises) {
          for (final set in exercise.sets) {
            if (set.isCompleted) {
              sessionVolume += set.reps * set.weight;
            }
          }
        }

        aggregatedVolume += sessionVolume;

        // Group volume by date
        final date = DateTime(session.startTime.year, session.startTime.month, session.startTime.day);
        dailyVolume[date] = (dailyVolume[date] ?? 0.0) + sessionVolume;
      }

      // Calculate average accuracy
      double totalAccuracySum = 0.0;
      int poseCount = 0;
      final Map<String, List<double>> accuracyPerExMap = {};

      for (final pose in poses) {
        if (pose.averageAccuracy > 0.0) {
          totalAccuracySum += pose.averageAccuracy;
          poseCount++;

          accuracyPerExMap[pose.exerciseName] = (accuracyPerExMap[pose.exerciseName] ?? [])
            ..add(pose.averageAccuracy);
        }
      }

      final avgAccuracy = poseCount == 0 ? 0.0 : totalAccuracySum / poseCount;

      // 6. Build Line Chart Data (sort by Date chronologically)
      final volumeHistory = dailyVolume.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      // 7. Build Bar Chart Data (average accuracy per exercise)
      final accuracyPerExercise = accuracyPerExMap.entries.map((entry) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        return MapEntry(entry.key, avg);
      }).toList();

      state = AnalyticsState(
        lookbackDays: state.lookbackDays,
        isLoading: false,
        totalVolume: aggregatedVolume,
        completedSessions: sessions.length,
        averageAccuracy: avgAccuracy,
        totalMinutes: aggregatedDurationSec ~/ 60,
        volumeHistory: volumeHistory,
        accuracyPerExercise: accuracyPerExercise,
        muscleStats: muscleStats,
      );
    } catch (e) {
      debugPrint('Analytics aggregation failed: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Aggregation failed: $e',
      );
    }
  }

  static Map<String, MuscleStat> aggregateMuscleStats(
    List<WorkoutSessionModel> sessions,
    Map<String, String> exerciseMuscleMap,
  ) {
    final muscleTotalVolumes = <String, double>{};
    final muscleExerciseCounts = <String, Map<String, int>>{};
    final muscleMaxWeights = <String, double>{}; // store highest raw weight
    final muscleSetsCount = <String, int>{};
    final muscleRepsCount = <String, int>{};

    for (final session in sessions) {
      for (final ex in session.exercises) {
        var targetMuscle = exerciseMuscleMap[ex.workoutId] ?? 'full_body';
        if (targetMuscle == 'full_body') {
          final titleLower = ex.title.toLowerCase();
          if (titleLower.contains('bench press') || titleLower.contains('push-up') || titleLower.contains('chest')) {
            targetMuscle = 'chest';
          } else if (titleLower.contains('squat') || titleLower.contains('lunge') || titleLower.contains('quad')) {
            targetMuscle = 'quadriceps';
          } else if (titleLower.contains('curl') || titleLower.contains('bicep')) {
            targetMuscle = 'biceps';
          } else if (titleLower.contains('plank') || titleLower.contains('crunch') || titleLower.contains('raise')) {
            targetMuscle = 'abs';
          } else if (titleLower.contains('pull-up') || titleLower.contains('row') || titleLower.contains('back')) {
            targetMuscle = 'upper_back';
          } else if (titleLower.contains('deadlift')) {
            targetMuscle = 'lower_back';
          } else if (titleLower.contains('press') || titleLower.contains('raise')) {
            targetMuscle = 'front_deltoids';
          } else if (titleLower.contains('tricep') || titleLower.contains('extension')) {
            targetMuscle = 'triceps';
          } else if (titleLower.contains('calf')) {
            targetMuscle = 'calves';
          } else if (titleLower.contains('hamstring') || titleLower.contains('curl')) {
            targetMuscle = 'hamstring';
          } else if (titleLower.contains('thrust') || titleLower.contains('glute')) {
            targetMuscle = 'gluteal';
          }
        }

        int completedSetsForExercise = 0;
        double maxWeightForExercise = 0.0;
        double volumeForExercise = 0.0;

        for (final set in ex.sets) {
          if (set.isCompleted) {
            completedSetsForExercise++;
            volumeForExercise += set.reps * set.weight;
            muscleRepsCount[targetMuscle] = (muscleRepsCount[targetMuscle] ?? 0) + set.reps;

            // Update maxWeightForExercise (raw weight used in any single set)
            if (set.weight > maxWeightForExercise) {
              maxWeightForExercise = set.weight;
            }
          }
        }

        if (completedSetsForExercise > 0) {
          // إجمالي الحجم التراكمي للعضلة
          muscleTotalVolumes[targetMuscle] = (muscleTotalVolumes[targetMuscle] ?? 0.0) + volumeForExercise;

          // إجمالي عدد المجموعات المستهدفة للعضلة
          muscleSetsCount[targetMuscle] = (muscleSetsCount[targetMuscle] ?? 0) + completedSetsForExercise;

          // تحديث maxWeight للعضلة ككل بأعلى وزن مستخدم في أي مجموعة لأي تمرين يشمل هذه العضلة
          final currentMuscleMax = muscleMaxWeights[targetMuscle] ?? 0.0;
          if (maxWeightForExercise > currentMuscleMax) {
            muscleMaxWeights[targetMuscle] = maxWeightForExercise;
          }

          final exMap = muscleExerciseCounts[targetMuscle] ?? {};
          exMap[ex.title] = (exMap[ex.title] ?? 0) + 1;
          muscleExerciseCounts[targetMuscle] = exMap;
        }
      }
    }

    final muscleStats = <String, MuscleStat>{};
    muscleTotalVolumes.forEach((muscle, totalVol) {
      final totalSets = muscleSetsCount[muscle] ?? 0;
      final totalReps = muscleRepsCount[muscle] ?? 0;
      final maxWeight = muscleMaxWeights[muscle] ?? 0.0;

      final exMap = muscleExerciseCounts[muscle] ?? {};
      final sortedExercises = exMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTitles = sortedExercises.take(3).map((e) => e.key).toList();

      muscleStats[muscle] = MuscleStat(
        muscleName: muscle,
        totalSets: totalSets,
        totalReps: totalReps,
        totalVolume: totalVol,
        maxWeight: maxWeight,
        topExercises: topTitles,
      );
    });

    return muscleStats;
  }

  List<WorkoutSessionModel> _generateMockSessions(String uid, int days) {
    final list = <WorkoutSessionModel>[];
    final now = DateTime.now();

    for (int i = days; i >= 1; i -= 2) {
      final sessionDate = now.subtract(Duration(days: i, hours: 2));
      final exercises = <ExerciseSessionModel>[];
      
      if (i % 3 == 0) {
        exercises.addAll([
          ExerciseSessionModel(
            workoutId: 'bench_press',
            title: 'Barbell Bench Press',
            sets: [
              SetSessionModel(reps: 10, weight: 60.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 70.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 80.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 80.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'overhead_press',
            title: 'Overhead Press',
            sets: [
              SetSessionModel(reps: 10, weight: 40.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 45.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 45.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'pushups',
            title: 'Push-Ups',
            sets: [
              SetSessionModel(reps: 20, weight: 0.0, isCompleted: true),
              SetSessionModel(reps: 15, weight: 0.0, isCompleted: true),
            ],
          ),
        ]);
      } else if (i % 3 == 1) {
        exercises.addAll([
          ExerciseSessionModel(
            workoutId: 'pull_ups',
            title: 'Pull-Ups',
            sets: [
              SetSessionModel(reps: 10, weight: 0.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 0.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 0.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'barbell_row',
            title: 'Barbell Row',
            sets: [
              SetSessionModel(reps: 12, weight: 50.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 60.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 60.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'barbell_curl',
            title: 'Barbell Curl',
            sets: [
              SetSessionModel(reps: 12, weight: 25.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 30.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 30.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'plank',
            title: 'Plank',
            sets: [
              SetSessionModel(reps: 1, weight: 0.0, isCompleted: true),
              SetSessionModel(reps: 1, weight: 0.0, isCompleted: true),
            ],
          ),
        ]);
      } else {
        exercises.addAll([
          ExerciseSessionModel(
            workoutId: 'squats',
            title: 'Barbell Back Squat',
            sets: [
              SetSessionModel(reps: 10, weight: 80.0, isCompleted: true),
              SetSessionModel(reps: 10, weight: 90.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 100.0, isCompleted: true),
              SetSessionModel(reps: 8, weight: 100.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'deadlift',
            title: 'Deadlift',
            sets: [
              SetSessionModel(reps: 8, weight: 100.0, isCompleted: true),
              SetSessionModel(reps: 6, weight: 120.0, isCompleted: true),
              SetSessionModel(reps: 6, weight: 120.0, isCompleted: true),
            ],
          ),
          ExerciseSessionModel(
            workoutId: 'lunges',
            title: 'Walking Lunges',
            sets: [
              SetSessionModel(reps: 12, weight: 16.0, isCompleted: true),
              SetSessionModel(reps: 12, weight: 16.0, isCompleted: true),
            ],
          ),
        ]);
      }

      double totalWeight = 0;
      for (final ex in exercises) {
        for (final s in ex.sets) {
          totalWeight += s.reps * s.weight;
        }
      }

      list.add(
        WorkoutSessionModel(
          id: 'mock_session_$i',
          userId: uid,
          routineId: 'mock_routine',
          routineName: i % 3 == 0 ? 'Push Hypertrophy' : (i % 3 == 1 ? 'Pull Strength' : 'Leg Day'),
          startTime: sessionDate,
          endTime: sessionDate.add(const Duration(minutes: 45)),
          durationSeconds: 45 * 60,
          totalWeightKg: totalWeight > 0 ? totalWeight : 150.0,
          completedSetsPercentage: 100.0,
          exercises: exercises,
        ),
      );
    }
    return list;
  }

  List<PoseAnalysisResultModel> _generateMockPoses(int days) {
    final list = <PoseAnalysisResultModel>[];
    final now = DateTime.now();

    final exercises = [
      'Barbell Bench Press',
      'Overhead Press',
      'Push-Ups',
      'Pull-Ups',
      'Barbell Row',
      'Barbell Curl',
      'Barbell Back Squat',
      'Deadlift',
      'Plank',
    ];

    for (int i = 0; i < exercises.length; i++) {
      final exName = exercises[i];
      double avgAcc = 92.5 + (i % 3) * 1.5;
      if (exName == 'Barbell Back Squat' || exName == 'Deadlift') {
        avgAcc = 89.0 + (i % 2) * 1.5;
      }

      list.add(
        PoseAnalysisResultModel(
          id: 'mock_pose_$i',
          timestamp: now.subtract(Duration(days: (i * 2) % days + 1, minutes: 30)),
          exerciseName: exName,
          averageAccuracy: avgAcc,
          riskLevel: avgAcc >= 90.0 ? 'LOW' : 'MEDIUM',
          jointStress: exName == 'Barbell Back Squat'
              ? {'knees': 'GOOD', 'lower_back': 'WARNING'}
              : {'shoulders': 'GOOD', 'back': 'GOOD'},
          corrections: exName == 'Barbell Back Squat'
              ? ['Keep torso more upright', 'Ensure hips go parallel']
              : ['Maintain full range of motion'],
          durationSeconds: 120,
        ),
      );
    }
    return list;
  }
}

final analyticsProvider =
    NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);