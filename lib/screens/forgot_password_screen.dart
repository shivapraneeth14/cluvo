import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/google_logo.dart';
import '../supabase_client.dart';
import '../theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _clearGoogleOnly() {
    if (ref.read(authProvider).googleOnly) {
      ref.read(authProvider.notifier).setGoogleOnly(false);
    }
  }

  void _sendLink() {
    _clearGoogleOnly();
    final email = _emailController.text;
    if (email.isEmpty) {
      ref.read(authProvider.notifier).setError('Please enter your email address.');
      return;
    }
    ref.read(authProvider.notifier).sendResetLink(email);
  }

  Future<void> _signInWithGoogle() async {
    _clearGoogleOnly();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _googleLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'cluvo://login',
      );
    } catch (e) {
      setState(() => _googleLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
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
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your email and we'll send you a link to reset your password.",
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
              if (state.successMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.cluvoSuccessFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.cluvoSuccessBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: context.cluvoSuccessText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.successMessage!,
                          style: TextStyle(
                            color: context.cluvoSuccessText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              AuthTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _clearGoogleOnly(),
              ),
              const SizedBox(height: 24),
              AuthButton(
                label: 'Send Reset Link',
                isLoading: state.isLoading,
                onPressed: _sendLink,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: context.cluvoTextSecondary)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: context.cluvoTextSecondary),
                    ),
                  ),
                  Expanded(child: Divider(color: context.cluvoTextSecondary)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _googleLoading ? null : _signInWithGoogle,
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
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to Sign In'),
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