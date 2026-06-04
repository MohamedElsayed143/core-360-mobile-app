import 'set_config.dart';

class RoutineExercise {
  final String workoutId;
  final String title;
  final String targetMuscle;
  final List<SetConfig> sets;
  final int order;

  RoutineExercise({
    required this.workoutId,
    required this.title,
    required this.targetMuscle,
    required this.sets,
    required this.order,
  });

  RoutineExercise copyWith({
    String? workoutId,
    String? title,
    String? targetMuscle,
    List<SetConfig>? sets,
    int? order,
  }) {
    return RoutineExercise(
      workoutId: workoutId ?? this.workoutId,
      title: title ?? this.title,
      targetMuscle: targetMuscle ?? this.targetMuscle,
      sets: sets ?? this.sets,
      order: order ?? this.order,
    );
  }
}
