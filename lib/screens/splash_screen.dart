import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/consent_provider.dart';
import '../theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      final session = ref.read(authProvider).session;
      if (session == null) {
        context.go('/login');
        return;
      }

      // Consent is verified in the background. If the answer hasn't arrived
      // yet, stay on the splash screen: navigating now would bounce the user
      // through the consent gate for a moment even when they already accepted.
      // The router refreshes when the check resolves and continues to /home
      // or /consent from here.
      final consent = ref.read(consentProvider);
      if (consent.upToDate == null && consent.error == null) return;

      context.go(consent.upToDate == true ? '/home' : '/consent');
    } catch (_) {
      // Session check or navigation failed — redirect will handle it on next refresh
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CluvoTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CLUVO',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: context.cluvoTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting communities',
                style: TextStyle(
                  fontSize: 14,
                  color: context.cluvoTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
