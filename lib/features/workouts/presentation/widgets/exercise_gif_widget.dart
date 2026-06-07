import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';

/// An optimized widget for displaying exercise thumbnails and animated GIFs.
/// Handles caching via [CachedNetworkImage], isolates frame updates using
/// [RepaintBoundary], and supports interactive tap-to-play toggling to
/// optimize memory and prevent UI jank in long scrolling lists.
class ExerciseGifWidget extends StatefulWidget {
  final String gifUrl;
  final String thumbnailUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  final bool autoplay;

  const ExerciseGifWidget({
    super.key,
    required this.gifUrl,
    required this.thumbnailUrl,
    this.width = 50.0,
    this.height = 50.0,
    this.borderRadius,
    this.autoplay = true,
  });

  @override
  State<ExerciseGifWidget> createState() => _ExerciseGifWidgetState();
}

class _ExerciseGifWidgetState extends State<ExerciseGifWidget> {
  late bool _isPlaying;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.autoplay;
  }

  @override
  void didUpdateWidget(ExerciseGifWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gifUrl != widget.gifUrl) {
      _isPlaying = widget.autoplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(10);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          if (widget.gifUrl.isNotEmpty) {
            setState(() {
              _isPlaying = !_isPlaying;
            });
          }
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            color: AppTheme.glassFillColor,
            border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
          ),
          child: Stack(
            children: [
              // Display Image Content
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: effectiveBorderRadius - BorderRadius.circular(1.2),
                  child: _buildImageContent(),
                ),
              ),

              // Tap-to-play Overlay Badge when paused
              if (widget.gifUrl.isNotEmpty && !_isPlaying)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: effectiveBorderRadius,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.4), width: 1),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppTheme.cyberCyan,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),

              // "GIF" Badge in corner when paused
              if (widget.gifUrl.isNotEmpty && !_isPlaying)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.cyberCyan,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isPlaying && widget.gifUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.gifUrl,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.cyberCyan,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildThumbnailOrFallback(),
      );
    }

    return _buildThumbnailOrFallback();
  }

  Widget _buildThumbnailOrFallback() {
    if (widget.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        memCacheWidth: (widget.width * 3).toInt(), // downsample in memory for high-DPI screens
        memCacheHeight: (widget.height * 3).toInt(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

    // If both thumbnailUrl and gifUrl are empty/fail, we can display the first frame of the GIF statically (downsampled) if gifUrl is present
    if (widget.gifUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.gifUrl,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        memCacheWidth: (widget.width * 3).toInt(), // forces Flutter to load static resized frame
        memCacheHeight: (widget.height * 3).toInt(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return const Center(
      child: Icon(
        Icons.fitness_center,
        color: AppTheme.cyberCyan,
        size: 20,
      ),
    );
  }
}
