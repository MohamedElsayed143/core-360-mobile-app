class AiWorkoutRequest {
  final String goal;
  final String experience;
  final String frequency;
  final String focus;
  final String injuries;
  final List<String> availableExercises;

  AiWorkoutRequest({
    required this.goal,
    required this.experience,
    required this.frequency,
    required this.focus,
    required this.injuries,
    required this.availableExercises,
  });

  Map<String, dynamic> toJson() {
    return {
      'goal': goal,
      'experience': experience,
      'frequency': frequency,
      'focus': focus,
      'injuries': injuries,
      'availableExercises': availableExercises,
    };
  }
}

class AiWorkoutExercise {
  final String name;
  final int sets;
  final String reps;
  final String weightKg;
  final String rest;
  final String notes;
  final String? videoUrl;

  AiWorkoutExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weightKg,
    required this.rest,
    required this.notes,
    this.videoUrl,
  });

  factory AiWorkoutExercise.fromJson(Map<String, dynamic> json) {
    return AiWorkoutExercise(
      name: json['name'] as String? ?? '',
      sets: json['sets'] as int? ?? 0,
      reps: (json['reps'] ?? '').toString(),
      weightKg: (json['weightKg'] ?? '').toString(),
      rest: (json['rest'] ?? '').toString(),
      notes: json['notes'] as String? ?? '',
      videoUrl: json['videoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'weightKg': weightKg,
      'rest': rest,
      'notes': notes,
      if (videoUrl != null) 'videoUrl': videoUrl,
    };
  }
}

class AiWorkoutRoutine {
  final String routineName;
  final String summary;
  final List<AiWorkoutExercise> exercises;
  final List<String> warnings;

  AiWorkoutRoutine({
    required this.routineName,
    required this.summary,
    required this.exercises,
    required this.warnings,
  });

  factory AiWorkoutRoutine.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List? ?? [];
    final warningsJson = json['warnings'] as List? ?? [];
    return AiWorkoutRoutine(
      routineName: json['routineName'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      exercises: exercisesJson
          .map((e) => AiWorkoutExercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      warnings: warningsJson.map((w) => w.toString()).toList(),
    );
  }
}

class AiWorkoutResponse {
  final AiWorkoutRoutine routine;

  AiWorkoutResponse({required this.routine});

  factory AiWorkoutResponse.fromJson(Map<String, dynamic> json) {
    return AiWorkoutResponse(
      routine: AiWorkoutRoutine.fromJson(
        Map<String, dynamic>.from(json['routine'] as Map? ?? {}),
      ),
    );
  }
}
