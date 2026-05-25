import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/routine_exercise.dart';
import 'set_config_model.dart';

class RoutineExerciseModel extends RoutineExercise {
  RoutineExerciseModel({
    required super.workoutId,
    required super.title,
    required super.targetMuscle,
    required super.sets,
    required super.order,
  });

  factory RoutineExerciseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final setsList = data['sets'] as List? ?? [];
    return RoutineExerciseModel(
      workoutId: data['workoutId'] as String? ?? doc.id,
      title: data['title'] as String? ?? '',
      targetMuscle: data['targetMuscle'] as String? ?? '',
      sets: setsList
          .map((s) => SetConfigModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      order: data['order'] as int? ?? 0,
    );
  }

  factory RoutineExerciseModel.fromMap(Map<String, dynamic> map) {
    final setsList = map['sets'] as List? ?? [];
    return RoutineExerciseModel(
      workoutId: map['workoutId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      targetMuscle: map['targetMuscle'] as String? ?? '',
      sets: setsList
          .map((s) => SetConfigModel.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList(),
      order: map['order'] as int? ?? 0,
    );
  }

  factory RoutineExerciseModel.fromEntity(RoutineExercise entity) {
    return RoutineExerciseModel(
      workoutId: entity.workoutId,
      title: entity.title,
      targetMuscle: entity.targetMuscle,
      sets: entity.sets,
      order: entity.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workoutId': workoutId,
      'title': title,
      'targetMuscle': targetMuscle,
      'sets': sets.map((s) => SetConfigModel.fromEntity(s).toMap()).toList(),
      'order': order,
    };
  }
}
