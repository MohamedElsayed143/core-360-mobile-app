import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/exercise.dart';

class ExerciseModel extends Exercise {
  ExerciseModel({
    required super.id,
    required super.title,
    required super.description,
    required super.targetMuscle,
    required super.thumbnailUrl,
    required super.videoUrl,
    required super.aiSupported,
  });

  factory ExerciseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExerciseModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      targetMuscle: data['targetMuscle'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      aiSupported: data['aiSupported'] as bool? ?? false,
    );
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> data, String id) {
    return ExerciseModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      targetMuscle: data['targetMuscle'] as String? ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      aiSupported: data['aiSupported'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetMuscle': targetMuscle,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'aiSupported': aiSupported,
    };
  }
}
