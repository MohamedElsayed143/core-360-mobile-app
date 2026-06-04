import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/routine.dart';
import 'routine_exercise_model.dart';

class RoutineModel extends Routine {
  RoutineModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.exercises,
    super.isAiGenerated,
    super.shareCode,
    super.createdAt,
  });

  factory RoutineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    List<RoutineExerciseModel> exercises,
  ) {
    final data = doc.data() ?? {};
    final createdAtData = data['createdAt'];
    DateTime? createdAtDate;
    if (createdAtData is Timestamp) {
      createdAtDate = createdAtData.toDate();
    }
    return RoutineModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      exercises: exercises,
      isAiGenerated: data['isAiGenerated'] as bool? ?? false,
      shareCode: data['shareCode'] as String?,
      createdAt: createdAtDate,
    );
  }

  factory RoutineModel.fromEntity(Routine entity) {
    return RoutineModel(
      id: entity.id,
      userId: entity.userId,
      name: entity.name,
      exercises: entity.exercises,
      isAiGenerated: entity.isAiGenerated,
      shareCode: entity.shareCode,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'isAiGenerated': isAiGenerated,
      'shareCode': shareCode,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
