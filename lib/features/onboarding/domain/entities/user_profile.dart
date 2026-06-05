class UserProfile {
  final int age;
  final double height;
  final double weight;
  final double? bodyFat;
  final double? waterPercentage;
  final double? muscleMass;
  final List<String> goals;
  final String? injuries;
  final String? photoURL;

  UserProfile({
    required this.age,
    required this.height,
    required this.weight,
    this.bodyFat,
    this.waterPercentage,
    this.muscleMass,
    required this.goals,
    this.injuries,
    this.photoURL,
  });
}
