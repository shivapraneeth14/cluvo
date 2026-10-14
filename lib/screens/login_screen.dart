import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/google_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (prev, next) {
      if (!mounted) return;
      if (next.session != null && prev?.session != next.session) {
        context.go('/communities');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/splash'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Cluvo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Continue with Google to sign in or create your account',
                style: TextStyle(
                  fontSize: 15,
                  color: context.cluvoTextSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (state.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.cluvoErrorFill,
                    borderRadius: BorderRadius.circular(8),
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
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _googleLoading
                      ? null
                      : () async {
                          setState(() => _googleLoading = true);
                          try {
                            await clearLocalSessionForOAuth();
                            await supabase.auth.signInWithOAuth(
                              OAuthProvider.google,
                              redirectTo:
                                  kIsWeb ? Uri.base.origin : 'cluvo://login',
                            );
                          } catch (e) {
                            setState(() => _googleLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Google sign-in failed: $e')),
                              );
                            }
                          }
                        },
                  icon: _googleLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const GoogleLogo(size: 18),
                  label: Text(
                    _googleLoading ? 'Connecting...' : 'Continue with Google',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.cluvoTextPrimary,
                    side: BorderSide(color: context.cluvoTextSecondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
