// ============================================================================
// Unified full-screen media gallery — VIEW ONLY.
//
// One screen for both photos and videos. It walks the exact record list the
// caller was looking at (so the All / Photos / Videos filter is respected) and
// lets the user swipe horizontally through photo *and* video pages. Videos
// autoplay when they become the active page, pause when swiped away, and carry
// full playback controls; photos pinch-to-zoom / pan.
//
// There is deliberately no download, save, delete, edit, share or overflow
// action anywhere here: the media experience is view-only by product
// requirement.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import 'video_playback.dart';

bool _isVideo(Map<String, dynamic> item) => item['type'] == 'video';

String? _urlOf(Map<String, dynamic> item) {
  final url = (item['url'] as String?)?.trim();
  return (url == null || url.isEmpty) ? null : url;
}

String? _captionOf(Map<String, dynamic> item) {
  final caption = (item['caption'] as String?)?.trim();
  return (caption == null || caption.isEmpty) ? null : caption;
}

class MediaGalleryScreen extends StatefulWidget {
  /// The real, already-filtered records the user was looking at. The gallery
  /// never fetches or invents media; it only displays these records.
  final List<Map<String, dynamic>> items;

  /// Index into [items] of the item that was tapped.
  final int initialIndex;

  const MediaGalleryScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late final PageController _pageController;
  late int _index;

  /// True while the current photo is zoomed in. Horizontal page swiping is
  /// suspended in that state so the gesture pans the photo instead.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = widget.items.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;

    return Scaffold(
      backgroundColor: CluvoTheme.viewerBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: total,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (_, i) {
                  final item = widget.items[i];
                  if (_isVideo(item)) {
                    return VideoPlaybackView(
                      url: _urlOf(item) ?? '',
                      caption: _captionOf(item),
                      active: i == _index,
                    );
                  }
                  return _ZoomablePhoto(
                    url: _urlOf(item),
                    onZoomChanged: (zoomed) {
                      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                    },
                  );
                },
              ),
            ),

            // Close (system back stays available too).
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _ViewerCircleButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),

            // Real position within the collection — only when it is meaningful.
            if (total > 1)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_index + 1} / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ViewerCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final String? url;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePhoto({required this.url, required this.onZoomChanged});

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _transformation = TransformationController();

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transformation.removeListener(_onTransform);
    _transformation.dispose();
    super.dispose();
  }

  void _onTransform() {
    widget.onZoomChanged(_transformation.value.getMaxScaleOnAxis() > 1.01);
  }

  void _resetZoom() {
    _transformation.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;

    return GestureDetector(
      onDoubleTap: _resetZoom,
      child: InteractiveViewer(
        transformationController: _transformation,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: url == null
              ? const _PhotoFallback()
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, _) => const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const _PhotoFallback(),
                ),
        ),
      ),
    );
  }
}

/// Neutral fallback that preserves the layout when a photo cannot be loaded.
class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
    );
  }
}
