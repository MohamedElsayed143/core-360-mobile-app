class Exercise {
  final String id;
  final String title;
  final String description;
  final String targetMuscle;
  final String thumbnailUrl;
  final String videoUrl;
  final String gifUrl;
  final bool aiSupported;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.targetMuscle,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.gifUrl = '',
    required this.aiSupported,
  });
}
