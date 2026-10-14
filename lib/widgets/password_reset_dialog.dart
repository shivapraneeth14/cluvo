import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../supabase_client.dart';
import '../theme.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_logo.dart';

enum _ResetStep { email, otp, password }

const _ttlSeconds = 600; // 10 minutes, matches the server
const _resendCooldownSeconds = 30;

/// In-app password reset. Everything happens inside one dialog box:
/// email -> 6-digit OTP -> new password + confirm. No page navigation, so the
/// user can cancel any time and nothing ever signs them in (no "bounce to
/// dashboard" possible). All three server calls are made with the anon key.
class PasswordResetDialog extends ConsumerStatefulWidget {
  final String initialEmail;
  final void Function(String email)? onSuccess;

  const PasswordResetDialog({super.key, this.initialEmail = '', this.onSuccess});

  static Future<void> show(
    BuildContext context, {
    String initialEmail = '',
    void Function(String email)? onSuccess,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PasswordResetDialog(
        initialEmail: initialEmail,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  ConsumerState<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends ConsumerState<PasswordResetDialog> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpFocus = FocusNode();

  _ResetStep _step = _ResetStep.email;
  bool _busy = false;
  String? _error;
  String? _info;
  String? _successMessage;
  bool _showGoogle = false;
  String? _resetToken;
  DateTime? _expiresAt;
  DateTime? _resendLockUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _stopTicker();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  int get _expirySeconds =>
      _expiresAt == null ? 0 : _expiresAt!.difference(DateTime.now()).inSeconds;
  bool get _expired => _expiresAt != null && _expirySeconds <= 0;
  int get _resendSeconds => _resendLockUntil == null
      ? 0
      : _resendLockUntil!.difference(DateTime.now()).inSeconds;
  bool get _canResend => _resendLockUntil == null || _resendSeconds <= 0;

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _sendOtp() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() { _error = 'Please enter your email address.'; _info = null; });
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() { _error = 'Please enter a valid email address.'; _info = null; });
      return;
    }

    setState(() { _busy = true; _error = null; _info = null; });
    final result = await ref.read(authProvider.notifier).sendOtp(email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.sent) {
      setState(() {
        _showGoogle = false;
        _expiresAt = DateTime.now().add(const Duration(seconds: _ttlSeconds));
        _resendLockUntil =
            DateTime.now().add(const Duration(seconds: _resendCooldownSeconds));
        _error = null;
        _info = null;
        _otpController.clear();
        _step = _ResetStep.otp;
      });
      _startTicker();
      _otpFocus.requestFocus();
    } else {
      setState(() {
        // No-enumeration copy (or a genuine delivery/network error) — stay on
        // the email step and offer Google, matching the neutral message.
        _showGoogle = true;
        if (result.unified) {
          _info = result.message ??
              'If your email uses password login, a code has been sent. '
                  'If it uses Google, please sign in with Google instead.';
          _error = null;
        } else {
          _error = result.message ?? 'Something went wrong. Try again.';
          _info = null;
        }
      });
    }
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _otpController.text.trim();
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Please enter the 6-digit code from the email.');
      return;
    }

    setState(() { _busy = true; _error = null; });
    final result =
        await ref.read(authProvider.notifier).verifyOtp(_emailController.text.trim(), code);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.token != null) {
      setState(() {
        _resetToken = result.token;
        _error = null;
        _step = _ResetStep.password;
      });
      _stopTicker();
    } else {
      setState(() => _error = result.error ?? 'Invalid or expired code. Try again.');
    }
  }

  Future<void> _submitPassword() async {
    if (_busy) return;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty) {
      setState(() => _error = 'Please enter a new password.');
      return;
    }
    if (confirm.isEmpty) {
      setState(() => _error = 'Please confirm your password.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    final passwordError = validatePassword(password);
    if (passwordError != null) {
      setState(() => _error = passwordError);
      return;
    }
    final token = _resetToken;
    if (token == null) {
      setState(() => _error = 'This reset session has expired. Please start again.');
      return;
    }

    setState(() { _busy = true; _error = null; });
    final result = await ref.read(authProvider.notifier).changePasswordForReset(token, password);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      setState(() {
        _successMessage = 'Password updated — sign in with your new password.';
        _error = null;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      widget.onSuccess?.call(_emailController.text.trim());
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error ?? 'Could not update your password. Try again.');
    }
  }

  Future<void> _signInWithGoogle() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await clearLocalSessionForOAuth();
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'cluvo://login',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
  }

  void _cancel() => Navigator.of(context).pop();

  String get _title => switch (_step) {
        _ResetStep.email => 'Reset Password',
        _ResetStep.otp => 'Enter the code',
        _ResetStep.password => 'Set New Password',
      };

  String get _subtitle => switch (_step) {
        _ResetStep.email => 'Enter your email and we\'ll send you a 6-digit code.',
        _ResetStep.otp =>
          'We sent a code to ${_emailController.text.trim()}. It expires in 10 minutes.',
        _ResetStep.password => 'Enter your new password below.',
      };

  Widget _messageBox({
    required Color fill,
    required Color border,
    required Color text,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: text, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _errorBox(String message) => _messageBox(
        fill: context.cluvoErrorFill,
        border: context.cluvoErrorBorder,
        text: context.cluvoErrorText,
        message: message,
      );

  Widget _infoBox(String message) => _messageBox(
        fill: context.cluvoChipFill,
        border: context.cluvoBorder,
        text: context.cluvoTextSecondary,
        message: message,
      );

  Widget _successBox(String message) => _messageBox(
        fill: context.cluvoSuccessFill,
        border: context.cluvoSuccessBorder,
        text: context.cluvoSuccessText,
        message: message,
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cluvoSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    color: context.cluvoTextSecondary,
                    onPressed: _busy ? null : _cancel,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: context.cluvoTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (_successMessage != null) ...[
                _successBox(_successMessage!),
              ] else if (_step == _ResetStep.email) ...[
                if (_error != null) _errorBox(_error!),
                if (_info != null) _infoBox(_info!),
                AuthTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (!_busy && (_error != null || _info != null || _showGoogle)) {
                      setState(() { _error = null; _info = null; });
                    }
                  },
                ),
                const SizedBox(height: 20),
                AuthButton(
                  label: 'Send OTP',
                  isLoading: _busy,
                  onPressed: _sendOtp,
                ),
                if (_showGoogle) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: kIsWeb
                          ? const SizedBox.shrink()
                          : const GoogleLogo(size: 18),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.cluvoTextPrimary,
                        side: BorderSide(color: context.cluvoBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ] else if (_step == _ResetStep.otp) ...[
                if (_error != null) _errorBox(_error!),
                AuthTextField(
                  label: '6-digit code',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  hint: '123456',
                  focusNode: _otpFocus,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _expired
                      ? 'Code expired — request a new one.'
                      : 'Code expires in ${_mmss(_expirySeconds)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _expired ? context.cluvoErrorText : context.cluvoTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                AuthButton(
                  label: 'Verify Code',
                  isLoading: _busy,
                  enabled: !_expired,
                  onPressed: _verify,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _canResend && !_busy
                          ? _sendOtp
                          : null,
                      child: Text(
                        _canResend ? 'Resend OTP' : 'Resend in ${_resendSeconds}s',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _stopTicker();
                                _expiresAt = null;
                                _resendLockUntil = null;
                                _error = null;
                                _info = null;
                                _showGoogle = false;
                                _step = _ResetStep.email;
                              }),
                      child: const Text('Use a different email', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ] else if (_step == _ResetStep.password) ...[
                if (_error != null) _errorBox(_error!),
                AuthTextField(
                  label: 'New Password',
                  controller: _passwordController,
                  obscureText: true,
                  showToggle: true,
                  helperText: '8+ characters, 1 capital letter',
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Confirm Password',
                  controller: _confirmController,
                  obscureText: true,
                  showToggle: true,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 20),
                AuthButton(
                  label: 'Update Password',
                  isLoading: _busy,
                  onPressed: _submitPassword,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}