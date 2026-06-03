class Exercise {
  final String id;
  final String title;
  final String description;
  final String targetMuscle;
  final String thumbnailUrl;
  final String videoUrl;
  final bool aiSupported;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.targetMuscle,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.aiSupported,
  });

  String? get gifUrl {
    if (videoUrl.isEmpty) return null;
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    final vidId = uri.queryParameters['v'];
    if (vidId == null || vidId.isEmpty) return null;
    return 'https://i.ytimg.com/vi/$vidId/hqdefault_anime_webp.gif';
  }
}
