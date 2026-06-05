import 'dart:convert';

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

  /// Returns a human-readable sets description e.g. "3 × 12 reps"
  String get setsDisplay {
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(sets);
    if (match != null) {
      final count = match.group(1);
      final reps = match.group(2);
      return '$count × $reps reps';
    }
    try {
      final parsed = sets as Object;
      if (parsed is List) {
        final count = parsed.length;
        if (parsed.isNotEmpty && parsed[0] is Map) {
          final reps = parsed[0]['reps'];
          return '$count × $reps reps';
        }
        return '$count sets';
      }
    } catch (_) {}
    return sets;
  }

  factory ProposalExercise.fromJson(Map<String, dynamic> json) {
    String rawSets;
    final setsValue = json['sets'];
    if (setsValue is List) {
      rawSets = jsonEncode(setsValue);
    } else {
      rawSets = (setsValue ?? '').toString();
    }

    return ProposalExercise(
      name: (json['name'] ?? json['title'] ?? '') as String,
      key: (json['key'] ?? json['workoutId'] ?? json['id'] ?? '') as String,
      sets: rawSets,
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
