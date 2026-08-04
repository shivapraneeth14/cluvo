// ============================================================================
// NEW — CommunityPhotoGrid
// A two-column photo/video grid used ONLY on the redesigned community detail
// page's "Photos" tab. This is intentionally a SEPARATE widget from
// widgets/media_gallery.dart (the original horizontal filmstrip), since that
// widget may be reused elsewhere in the app (e.g. an event detail screen) —
// redesigning it in place could change behavior on other screens that were
// never part of this redesign request. Full-screen image/video viewing reuses
// the same simple pattern as the original for consistency.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';

class CommunityPhotoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  const CommunityPhotoGrid({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 36, color: context.cluvoTextSecondary),
              const SizedBox(height: 10),
              Text('No photos yet.',
                  style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13.5)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: media.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final item = media[index];
        final url = item['url'] as String;
        final isVideo = item['type'] == 'video';
        final thumb = isVideo ? (item['thumbnail_url'] as String?) : url;

        return GestureDetector(
          onTap: () => _openMedia(context, item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null && thumb.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _placeholder(context, isVideo),
                    errorWidget: (_, _, _) => _placeholder(context, isVideo),
                  )
                else
                  _placeholder(context, isVideo),
                if (isVideo)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context, bool isVideo) {
    return Container(
      color: isVideo ? Colors.black87 : CluvoTheme.primary.withValues(alpha: 0.1),
      child: Icon(
        isVideo ? Icons.play_circle_fill : Icons.broken_image,
        color: isVideo ? Colors.white : CluvoTheme.primary,
        size: 24,
      ),
    );
  }

  void _openMedia(BuildContext context, Map<String, dynamic> item) {
    final url = item['url'] as String;
    final isVideo = item['type'] == 'video';
    if (isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _VideoViewerScreen(url: url)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
            body: Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class _VideoViewerScreen extends StatefulWidget {
  final String url;
  const _VideoViewerScreen({required this.url});

  @override
  State<_VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<_VideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      controller.play();
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _errorMessage =
            error is PlatformException ? error.message ?? error.toString() : error.toString();
      });
    });
  }

  void _retry() {
    _controller?.dispose();
    setState(() {
      _initialized = false;
      _failed = false;
      _errorMessage = null;
      _controller = null;
    });
    _initController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: context.cluvoTextSecondary),
                    const SizedBox(height: 12),
                    const Text('Could not play this video.',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.cluvoTextSecondary, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                    ),
                  ],
                ),
              )
            : !_initialized
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: _togglePlay,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller!),
                          if (_controller!.value.isBuffering) const CircularProgressIndicator(),
                          if (!_controller!.value.isPlaying && !_controller!.value.isBuffering)
                            const Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: VideoProgressIndicator(
                              _controller!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: CluvoTheme.primary,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
