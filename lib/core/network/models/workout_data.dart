class WorkoutData {
  final String title;
  final String? videoUrl;
  final String? gifUrl;
  final String? description;
  final String? targetMuscle;

  WorkoutData({
    required this.title,
    this.videoUrl,
    this.gifUrl,
    this.description,
    this.targetMuscle,
  });
}
