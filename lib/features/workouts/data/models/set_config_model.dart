import '../../domain/entities/set_config.dart';

class SetConfigModel extends SetConfig {
  SetConfigModel({
    required super.reps,
    required super.weight,
  });

  factory SetConfigModel.fromMap(Map<String, dynamic> map) {
    return SetConfigModel(
      reps: map['reps'] as int? ?? 0,
      weight: (map['kg'] as num? ?? 0.0).toDouble(),
    );
  }

  factory SetConfigModel.fromEntity(SetConfig entity) {
    return SetConfigModel(
      reps: entity.reps,
      weight: entity.weight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reps': reps,
      'kg': weight,
    };
  }
}
