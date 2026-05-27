import 'package:cloud_firestore/cloud_firestore.dart';

class PoseAnalysisResultModel {
  final String id;
  final DateTime timestamp;
  final String exerciseName;
  final double averageAccuracy;
  final String riskLevel; // 'LOW', 'MEDIUM', 'HIGH'
  final Map<String, String> jointStress; // e.g., {'knees': 'GOOD', 'back': 'WARNING'}
  final List<String> corrections;
  final int durationSeconds;

  PoseAnalysisResultModel({
    required this.id,
    required this.timestamp,
    required this.exerciseName,
    required this.averageAccuracy,
    required this.riskLevel,
    required this.jointStress,
    required this.corrections,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'exerciseName': exerciseName,
      'averageAccuracy': averageAccuracy,
      'riskLevel': riskLevel,
      'jointStress': jointStress,
      'corrections': corrections,
      'durationSeconds': durationSeconds,
    };
  }

  factory PoseAnalysisResultModel.fromMap(Map<String, dynamic> map) {
    final timestampVal = map['timestamp'];
    DateTime dt = DateTime.now();
    if (timestampVal is Timestamp) {
      dt = timestampVal.toDate();
    } else if (timestampVal is String) {
      dt = DateTime.tryParse(timestampVal) ?? DateTime.now();
    }

    return PoseAnalysisResultModel(
      id: map['id'] ?? '',
      timestamp: dt,
      exerciseName: map['exerciseName'] ?? '',
      averageAccuracy: (map['averageAccuracy'] as num?)?.toDouble() ?? 0.0,
      riskLevel: map['riskLevel'] ?? 'LOW',
      jointStress: Map<String, String>.from(map['jointStress'] ?? {}),
      corrections: List<String>.from(map['corrections'] ?? []),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
