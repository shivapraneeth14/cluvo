// ============================================================================
// Reusable video playback surface.
//
// Plays a real media URL with a real VideoPlayerController and normal playback
// controls only: play/pause, seek, elapsed/total time, mute and a full-screen
// (landscape) toggle, plus a real error + retry state. No download / save /
// media management actions exist here.
//
// Shared by the full-screen media gallery (one view per video page) so playback
// stays byte-for-byte consistent everywhere.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../theme.dart';

// Cloudinary originals can be 4K+ (e.g. phone .mov files) which many mobile
// hardware decoders reject ("format supported=NO_exceeds_capabilities").
// Rewrite delivery URLs to request a 1080p mp4 instead; Cloudinary serves the
// pre-generated eager derivative or transcodes on the fly.
String cloudinaryPlayableVideoUrl(String url) {
  const marker = '/video/upload/';
  final idx = url.indexOf(marker);
  if (idx < 0) return url;
  final rest = url.substring(idx + marker.length);
  if (!RegExp(r'^v\d+/').hasMatch(rest)) {
    return url; // transformation already present
  }
  final noExt = rest.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,5}(\?.*)?$'), '');
  return '${url.substring(0, idx + marker.length)}w_1080,q_auto/$noExt.mp4';
}

/// Full-bleed video surface with controls. When [active] is false the video is
/// paused; the gallery flips this as pages change so only the visible video
/// ever plays.
class VideoPlaybackView extends StatefulWidget {
  /// The real media URL as stored in the backend.
  final String url;

  /// Optional real caption, when the record has one.
  final String? caption;

  /// Whether this view is the currently-visible page.
  final bool active;

  const VideoPlaybackView({
    super.key,
    required this.url,
    this.caption,
    this.active = true,
  });

  @override
  State<VideoPlaybackView> createState() => _VideoPlaybackViewState();
}

class _VideoPlaybackViewState extends State<VideoPlaybackView>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _failed = false;
  String? _errorMessage;
  bool _controlsVisible = true;
  bool _landscape = false;
  double? _dragMillis;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void didUpdateWidget(covariant VideoPlaybackView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    final controller = _controller;
    if (!widget.active) {
      controller?.pause();
      _hideTimer?.cancel();
      _showControls();
    } else if (controller != null && controller.value.isInitialized) {
      controller.play();
      _scheduleHideControls();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    if (_landscape) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _initController() {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(cloudinaryPlayableVideoUrl(widget.url)),
    );
    _controller = controller;
    controller.addListener(_onControllerChanged);
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _initializing = false);
          if (widget.active) {
            controller.play();
            _scheduleHideControls();
          }
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
            _failed = true;
            _errorMessage = error is PlatformException
                ? error.message ?? error.toString()
                : error.toString();
          });
        });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
      _showControls();
    }
  }

  void _retry() {
    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
    setState(() {
      _initializing = true;
      _failed = false;
      _errorMessage = null;
    });
    _initController();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _hideTimer?.cancel();
      } else {
        controller.play();
        _scheduleHideControls();
      }
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final playing = _controller?.value.isPlaying ?? false;
      if (playing) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_landscape) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (!mounted) return;
    setState(() => _landscape = !_landscape);
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    setState(() => controller.setVolume(controller.value.volume > 0 ? 0 : 1));
  }

  String _format(Duration? duration) {
    final d = duration ?? Duration.zero;
    final hours = d.inHours;
    final minutes = d.inMinutes
        .remainder(60)
        .toString()
        .padLeft(hours > 0 ? 2 : 1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Tap anywhere on the video area to toggle the controls.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: _buildStage(),
          ),
        ),

        if (!_failed && !_initializing) ...[
          if (_controlsVisible) _buildCenterPlayPause(),
          if (_controlsVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomControls(),
            ),
        ],

        if (_initializing) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildStage() {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      if (_failed) return _buildError();
      return const SizedBox.shrink();
    }

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspect = controller.value.aspectRatio <= 0
              ? 16 / 9
              : controller.value.aspectRatio;
          var width = constraints.maxWidth;
          var height = width / aspect;
          if (height > constraints.maxHeight) {
            height = constraints.maxHeight;
            width = height * aspect;
          }
          return SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                if (controller.value.isBuffering)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterPlayPause() {
    final playing = _controller?.value.isPlaying ?? false;
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final controller = _controller;
    final value = controller?.value;
    final durationMs = value?.duration.inMilliseconds.toDouble() ?? 0;
    final safeMax = durationMs <= 0 ? 1.0 : durationMs;
    final positionMs =
        (_dragMillis ?? value?.position.inMilliseconds.toDouble() ?? 0).clamp(
          0.0,
          safeMax,
        );
    final muted = (value?.volume ?? 1) <= 0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _format(Duration(milliseconds: positionMs.round())),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: positionMs,
                          max: safeMax,
                          activeColor: CluvoTheme.primary,
                          inactiveColor: Colors.white24,
                          onChangeStart: (v) => setState(() => _dragMillis = v),
                          onChanged: (v) => setState(() => _dragMillis = v),
                          onChangeEnd: (v) async {
                            final target = Duration(milliseconds: v.round());
                            setState(() => _dragMillis = null);
                            await controller?.seekTo(target);
                          },
                        ),
                      ),
                    ),
                    Text(
                      _format(value?.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(
                        (value?.isPlaying ?? false)
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      tooltip: (value?.isPlaying ?? false) ? 'Pause' : 'Play',
                    ),
                    IconButton(
                      onPressed: _toggleMute,
                      icon: Icon(
                        muted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      tooltip: muted ? 'Unmute' : 'Mute',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleFullscreen,
                      icon: Icon(
                        _landscape ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                      ),
                      tooltip: _landscape ? 'Exit full screen' : 'Full screen',
                    ),
                  ],
                ),
                if (widget.caption != null && widget.caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
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

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 44),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
      ),
    );
  }
}
