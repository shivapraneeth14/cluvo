import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_logo.dart';
import '../widgets/terms_checkbox.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (prev, next) {
      if (!mounted) return;
      if (next.session != null && prev?.session != next.session) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            const Positioned.fill(child: _AnimatedWallpaper()),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        CluvoTheme.primary.withValues(alpha: 0.28),
                        Colors.transparent,
                        const Color(0xFF000000).withValues(alpha: 0.52),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Expanded(flex: 3, child: SizedBox()),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Cluvo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              fontSize: 52,
                              height: 1.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Connecting communities',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(flex: 2, child: SizedBox()),
                    if (state.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.cluvoErrorBorder),
                        ),
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: context.cluvoErrorText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      child: TermsCheckbox(
                        value: _termsAccepted,
                        onChanged: (v) => setState(() => _termsAccepted = v),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: !_termsAccepted || _googleLoading
                            ? null
                            : () async {
                                setState(() => _googleLoading = true);
                                try {
                                  await clearLocalSessionForOAuth();
                                  await supabase.auth.signInWithOAuth(
                                    OAuthProvider.google,
                                    redirectTo: kIsWeb
                                        ? Uri.base.origin
                                        : 'cluvo://login',
                                  );
                                } catch (e) {
                                  setState(() => _googleLoading = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Google sign-in failed: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: _googleLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const GoogleLogo(size: 20),
                        label: Text(
                          _googleLoading
                              ? 'Connecting...'
                              : 'Continue with Google',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF000000),
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.7,
                          ),
                          disabledForegroundColor: const Color(
                            0xFF000000,
                          ).withValues(alpha: 0.6),
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen animated "living wallpaper": a pure black base with drifting
// amber/white accents for a high-contrast, premium dark look.
class _AnimatedWallpaper extends StatefulWidget {
  const _AnimatedWallpaper();

  @override
  State<_AnimatedWallpaper> createState() => _AnimatedWallpaperState();
}

class _AnimatedWallpaperState extends State<_AnimatedWallpaper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return CustomPaint(
        painter: _WallpaperPainter(0),
        child: const SizedBox.expand(),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _WallpaperPainter(_controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  final double t;

  _WallpaperPainter(this.t);

  static const Color _black = Color(0xFF000000);
  static const Color _violet = CluvoTheme.primary;
  static const Color _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final tau = 2 * math.pi;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + 0.4 * math.sin(t * tau), -1),
        end: Alignment(1, 1 + 0.4 * math.cos(t * tau)),
        colors: const [_black, _black],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    _blob(
      canvas,
      color: _violet,
      opacity: 0.20,
      center: Offset(
        w * (0.25 + 0.18 * math.sin(t * tau)),
        h * (0.30 + 0.14 * math.cos(t * tau)),
      ),
      radius: size.shortestSide * 0.75,
    );
    _blob(
      canvas,
      color: _white,
      opacity: 0.10,
      center: Offset(
        w * (0.78 + 0.16 * math.cos(t * tau)),
        h * (0.72 + 0.15 * math.sin(t * tau)),
      ),
      radius: size.shortestSide * 0.80,
    );
    _blob(
      canvas,
      color: _violet,
      opacity: 0.24,
      center: Offset(
        w * (0.55 + 0.22 * math.cos(t * tau + 1.2)),
        h * (0.15 + 0.20 * math.sin(t * tau + 1.2)),
      ),
      radius: size.shortestSide * 0.55,
    );
  }

  void _blob(
    Canvas canvas, {
    required Color color,
    required double opacity,
    required Offset center,
    required double radius,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) => oldDelegate.t != t;
}
