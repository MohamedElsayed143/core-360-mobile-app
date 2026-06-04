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
  final double totalVolume;
  final List<String> topExercises;

  MuscleStat({
    required this.muscleName,
    required this.totalSets,
    required this.totalVolume,
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
  @override
  AnalyticsState build() {
    // Initialise loading stats
    Future.microtask(() => refresh());
    return AnalyticsState();
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
      final sessions = sessionsSnap.docs
          .map((doc) => WorkoutSessionModel.fromFirestore(doc))
          .where((s) => s.startTime.isAfter(lookbackDate))
          .toList();

      // 4. Map & filter pose results locally
      final poses = posesSnap.docs
          .map((doc) => PoseAnalysisResultModel.fromMap(doc.data()))
          .where((p) => p.timestamp.isAfter(lookbackDate))
          .toList();

      // 5. Aggregate KPIs
      double aggregatedVolume = 0.0;
      int aggregatedDurationSec = 0;
      
      final Map<DateTime, double> dailyVolume = {};
      final Map<String, List<double>> muscleRepsCount = {};
      final Map<String, Map<String, int>> muscleExerciseCounts = {}; // Muscle -> {ExerciseTitle: count}

      for (final session in sessions) {
        aggregatedVolume += session.totalWeightKg;
        aggregatedDurationSec += session.durationSeconds;

        // Group volume by date
        final date = DateTime(session.startTime.year, session.startTime.month, session.startTime.day);
        dailyVolume[date] = (dailyVolume[date] ?? 0.0) + session.totalWeightKg;

        // Process muscles
        for (final ex in session.exercises) {
          final targetMuscle = exerciseMuscleMap[ex.workoutId] ?? 'full_body';
          
          int completedSets = 0;
          double volume = 0.0;
          for (final set in ex.sets) {
            if (set.isCompleted) {
              completedSets++;
              volume += set.reps * set.weight;
            }
          }

          if (completedSets > 0) {
            // Muscle stats accumulation
            muscleRepsCount[targetMuscle] = (muscleRepsCount[targetMuscle] ?? [])
              ..addAll(List.generate(completedSets, (_) => volume));
            
            // Exercise tracking within muscle group
            final exMap = muscleExerciseCounts[targetMuscle] ?? {};
            exMap[ex.title] = (exMap[ex.title] ?? 0) + 1;
            muscleExerciseCounts[targetMuscle] = exMap;
          }
        }
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

      // 8. Compile Muscle Heatmap matrix stats
      final Map<String, MuscleStat> muscleStats = {};
      muscleRepsCount.forEach((muscle, volumes) {
        final totalSets = volumes.length;
        final totalVol = volumes.isEmpty ? 0.0 : volumes.reduce((a, b) => a + b);
        
        // Sort top exercises by counts
        final exMap = muscleExerciseCounts[muscle] ?? {};
        final sortedExercises = exMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topTitles = sortedExercises.take(3).map((e) => e.key).toList();

        muscleStats[muscle] = MuscleStat(
          muscleName: muscle,
          totalSets: totalSets,
          totalVolume: totalVol,
          topExercises: topTitles,
        );
      });

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
}

final analyticsProvider =
    NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);
