class Exercise {
  final String id;
  final String title;
  final String description;
  final String targetMuscle;
  final String thumbnailUrl;
  final String videoUrl;
  final String _gifUrl;
  final bool aiSupported;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.targetMuscle,
    required this.thumbnailUrl,
    required this.videoUrl,
    String gifUrl = '',
    required this.aiSupported,
  }) : _gifUrl = gifUrl;

  String get gifUrl {
    if (_gifUrl.isNotEmpty) return _gifUrl;
    if (videoUrl.isEmpty) return '';
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return '';
    final vidId = uri.queryParameters['v'];
    if (vidId == null || vidId.isEmpty) return '';
    return 'https://i.ytimg.com/vi/$vidId/hqdefault_anime_webp.gif';
  }
}
