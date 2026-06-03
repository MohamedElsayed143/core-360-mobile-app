class SetConfig {
  final int reps;
  final double weight; // In kilograms

  SetConfig({
    required this.reps,
    required this.weight,
  });

  SetConfig copyWith({
    int? reps,
    double? weight,
  }) {
    return SetConfig(
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
    );
  }
}
