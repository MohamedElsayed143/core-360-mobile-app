import 'routine_exercise.dart';

class Routine {
  final String id;
  final String userId;
  final String name;
  final List<RoutineExercise> exercises;
  final bool isAiGenerated;
  final String? shareCode;
  final DateTime? createdAt;

  Routine({
    required this.id,
    required this.userId,
    required this.name,
    required this.exercises,
    this.isAiGenerated = false,
    this.shareCode,
    this.createdAt,
  });

  Routine copyWith({
    String? id,
    String? userId,
    String? name,
    List<RoutineExercise>? exercises,
    bool? isAiGenerated,
    String? shareCode,
    DateTime? createdAt,
  }) {
    return Routine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      shareCode: shareCode ?? this.shareCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
