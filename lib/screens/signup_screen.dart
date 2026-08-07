import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';
import '../widgets/google_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../legal_content.dart';
import '../widgets/terms_checkbox.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _googleLoading = false;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (prev, next) {
      if (!mounted) return;
      if (next.successMessage != null && prev?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        ref.read(authProvider.notifier).clearSuccess();
        context.go('/login');
      }
      if (next.session != null && prev?.session != next.session) {
        context.go('/communities');
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final email = _emailController.text;
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (firstName.isEmpty) {
      _showError('Please enter your first name.');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Please enter your last name.');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }
    if (username.isEmpty) {
      _showError('Please enter a username.');
      return;
    }
    final passwordError = validatePassword(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    if (!_termsAccepted) {
      _showError('Please accept the Privacy Policy and Terms of Service to continue.');
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    final available = await notifier.checkUsername(username);
    if (!available) {
      _showError('This username is already taken. Try another.');
      return;
    }

    notifier.signUp(
      email,
      password,
      firstName,
      lastName,
      username,
      consentAccepted: true,
      consentVersion: consentVersion,
      source: 'mobile',
    );
  }

  void _showError(String message) {
    ref.read(authProvider.notifier).setError(message);
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
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
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
              AuthTextField(
                label: 'First Name',
                controller: _firstNameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Last Name',
                controller: _lastNameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Username',
                controller: _usernameController,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                showToggle: true,
                helperText: '8+ characters, 1 capital letter',
              ),
              const SizedBox(height: 8),
              TermsCheckbox(
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v),
              ),
              const SizedBox(height: 8),
              AuthButton(
                label: 'Create Account',
                isLoading: state.isLoading || state.checkingUsername,
                enabled: _termsAccepted,
                onPressed: _signUp,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: (_googleLoading || !_termsAccepted)
                      ? null
                      : () async {
                          setState(() => _googleLoading = true);
                          try {
                            await supabase.auth.signInWithOAuth(
                              OAuthProvider.google,
                              redirectTo:
                                  kIsWeb ? Uri.base.origin : 'cluvo://signup',
                            );
                          } catch (e) {
                            setState(() => _googleLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Google sign-up failed: $e')),
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
                    _googleLoading ? 'Connecting...' : 'Sign up with Google',
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: context.cluvoTextSecondary),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
