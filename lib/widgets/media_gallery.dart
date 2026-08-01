import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../theme.dart';

class MediaGallery extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final String label;

  const MediaGallery({super.key, required this.media, this.label = 'Photos & Videos'});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final videos = media.where((m) => m['type'] == 'video').toList();
    final labelText = videos.isEmpty ? 'Photos' : label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = media[index];
              final url = item['url'] as String;
              final isVideo = item['type'] == 'video';
              final thumb = isVideo
                  ? (item['thumbnail_url'] as String?)
                  : url;

              return GestureDetector(
                onTap: () => _openMedia(context, item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 120,
                    height: 110,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumb != null && thumb.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            width: 120,
                            height: 110,
                            placeholder: (_, _) => _placeholder(isVideo),
                            errorWidget: (_, _, _) => _placeholder(isVideo),
                          )
                        else
                          _placeholder(isVideo),
                        if (isVideo)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 36),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _placeholder(bool isVideo) {
    return Container(
      color: isVideo ? Colors.black87 : CluvoTheme.primary.withValues(alpha: 0.1),
      child: Icon(
        isVideo ? Icons.play_circle_fill : Icons.broken_image,
        color: isVideo ? Colors.white : CluvoTheme.primary,
        size: 28,
      ),
    );
  }

  void _openMedia(BuildContext context, Map<String, dynamic> item) {
    final url = item['url'] as String;
    final isVideo = item['type'] == 'video';

    if (isVideo) {
      _openVideo(context, url);
    } else {
      _openImage(context, url);
    }
  }

  void _openImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
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

  void _openVideo(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoViewerScreen(url: url),
      ),
    );
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
      debugPrint('VideoPlayer initialize failed for ${widget.url}: $error');
      setState(() {
        _failed = true;
        _errorMessage = error is PlatformException
            ? error.message ?? error.toString()
            : error.toString();
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[500]),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not play this video.',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
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
                          if (_controller!.value.isBuffering)
                            const CircularProgressIndicator(),
                          if (!_controller!.value.isPlaying && !_controller!.value.isBuffering)
                            const Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 72),
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
