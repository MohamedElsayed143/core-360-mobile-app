import 'package:cloud_firestore/cloud_firestore.dart';

class SetSessionModel {
  final int reps;
  final double weight;
  final bool isCompleted;

  SetSessionModel({
    required this.reps,
    required this.weight,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'weight': weight,
      'isCompleted': isCompleted,
    };
  }

  factory SetSessionModel.fromMap(Map<String, dynamic> map) {
    return SetSessionModel(
      reps: map['reps'] as int? ?? 0,
      weight: (map['weight'] as num? ?? 0.0).toDouble(),
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }
}

class ExerciseSessionModel {
  final String workoutId;
  final String title;
  final List<SetSessionModel> sets;

  ExerciseSessionModel({
    required this.workoutId,
    required this.title,
    required this.sets,
  });

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'title': title,
      'sets': sets.map((s) => s.toMap()).toList(),
    };
  }

  factory ExerciseSessionModel.fromMap(Map<String, dynamic> map) {
    final rawSets = map['sets'] as List? ?? [];
    return ExerciseSessionModel(
      workoutId: map['workoutId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      sets: rawSets.map((s) => SetSessionModel.fromMap(Map<String, dynamic>.from(s as Map))).toList(),
    );
  }
}

class WorkoutSessionModel {
  final String id;
  final String userId;
  final String routineId;
  final String routineName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double totalWeightKg;
  final double completedSetsPercentage;
  final List<ExerciseSessionModel> exercises;

  WorkoutSessionModel({
    required this.id,
    required this.userId,
    required this.routineId,
    required this.routineName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.totalWeightKg,
    required this.completedSetsPercentage,
    required this.exercises,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'routineId': routineId,
      'routineName': routineName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'totalWeightKg': totalWeightKg,
      'completedSetsPercentage': completedSetsPercentage,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory WorkoutSessionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawExercises = data['exercises'] as List? ?? [];
    return WorkoutSessionModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      routineId: data['routineId'] as String? ?? '',
      routineName: data['routineName'] as String? ?? '',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      totalWeightKg: (data['totalWeightKg'] as num? ?? 0.0).toDouble(),
      completedSetsPercentage: (data['completedSetsPercentage'] as num? ?? 0.0).toDouble(),
      exercises: rawExercises.map((e) => ExerciseSessionModel.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}
