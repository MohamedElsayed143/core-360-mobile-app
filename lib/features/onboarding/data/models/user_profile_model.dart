import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_profile.dart';

class UserProfileModel extends UserProfile {
  UserProfileModel({
    required super.age,
    required super.height,
    required super.weight,
    super.bodyFat,
    super.waterPercentage,
    super.muscleMass,
    required super.goals,
    super.injuries,
  });

  /// Factory constructor to map from Firestore document snapshot
  factory UserProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfileModel(
      age: data['age'] as int? ?? 0,
      height: (data['height'] as num? ?? 0.0).toDouble(),
      weight: (data['weight'] as num? ?? 0.0).toDouble(),
      bodyFat: (data['bodyFat'] as num?)?.toDouble(),
      waterPercentage: (data['waterPercentage'] as num?)?.toDouble(),
      muscleMass: (data['muscleMass'] as num?)?.toDouble(),
      goals: List<String>.from(data['goals'] ?? []),
      injuries: data['injuries'] as String?,
    );
  }

  /// Factory constructor to map from clean entity representation
  factory UserProfileModel.fromEntity(UserProfile entity) {
    return UserProfileModel(
      age: entity.age,
      height: entity.height,
      weight: entity.weight,
      bodyFat: entity.bodyFat,
      waterPercentage: entity.waterPercentage,
      muscleMass: entity.muscleMass,
      goals: entity.goals,
      injuries: entity.injuries,
    );
  }

  /// Serializes instance into a Firestore map structure
  Map<String, dynamic> toFirestore() {
    return {
      'age': age,
      'height': height,
      'weight': weight,
      'bodyFat': bodyFat,
      'waterPercentage': waterPercentage,
      'muscleMass': muscleMass,
      'goals': goals,
      'injuries': injuries,
    };
  }
}
