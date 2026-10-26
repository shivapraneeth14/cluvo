// ============================================================================
// Lightweight autoplaying hero video surface.
//
// Unlike VideoPlaybackView (full gallery controls: play/pause, seek, time,
// fullscreen), this is a lean ambient player for the event-detail hero:
// autoplay + loop + mute/unmute only. It covers the hero area with BoxFit.cover
// and exposes a single tap target that toggles sound. When the video cannot be
// initialised it reports failure via [onFailed] so the caller can fall back to
// the event photo.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../theme.dart';
import 'video_playback.dart' show cloudinaryPlayableVideoUrl;

class HeroVideoView extends StatefulWidget {
  /// The real media URL as stored in the backend.
  final String url;

  /// Called when the video fails to load/initialise, so the hero can fall back
  /// to the event image.
  final VoidCallback? onFailed;

  /// Whether the video is muted. The parent hero owns this state and renders the
  /// mute button (kept outside this widget so the hero overlay can never cover
  /// it); we only apply the volume here.
  final bool muted;

  /// Whether this slide is the currently-visible hero page. When false the
  /// video is paused so an off-screen slide never keeps playing.
  final bool active;

  const HeroVideoView({
    super.key,
    required this.url,
    this.onFailed,
    this.muted = true,
    this.active = true,
  });

  @override
  State<HeroVideoView> createState() => _HeroVideoViewState();
}

class _HeroVideoViewState extends State<HeroVideoView>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void didUpdateWidget(covariant HeroVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
    if (oldWidget.active != widget.active) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        if (widget.active) {
          controller.play();
        } else {
          controller.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    super.dispose();
  }

  void _initController() {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(cloudinaryPlayableVideoUrl(widget.url)),
    );
    _controller = controller;
    controller.setVolume(widget.muted ? 0 : 1);
    controller.addListener(_onControllerChanged);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller.setLooping(true);
          setState(() => _initializing = false);
          if (widget.active) controller.play();
        })
        .catchError((Object _) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
            _failed = true;
          });
          widget.onFailed?.call();
        });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.active) _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = !_failed &&
        controller != null &&
        controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (_initializing)
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: CluvoTheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}
