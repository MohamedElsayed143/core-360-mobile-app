class ProposalExercise {
  final String name;
  final String key;
  final String sets;
  final String status; // 'upcoming', 'completed', etc.

  ProposalExercise({
    required this.name,
    required this.key,
    required this.sets,
    required this.status,
  });

  factory ProposalExercise.fromJson(Map<String, dynamic> json) {
    return ProposalExercise(
      name: json['name'] as String? ?? '',
      key: json['key'] as String? ?? '',
      sets: (json['sets'] ?? '').toString(),
      status: json['status'] as String? ?? 'upcoming',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'key': key,
      'sets': sets,
      'status': status,
    };
  }
}

class PlanProposalModel {
  final List<ProposalExercise> exercises;

  PlanProposalModel({required this.exercises});

  factory PlanProposalModel.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List? ?? [];
    return PlanProposalModel(
      exercises: exercisesJson
          .map((e) => ProposalExercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}
