import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/consent_provider.dart';
import '../theme.dart';
import '../widgets/legal_dialog.dart';
import '../legal_content.dart';
import '../widgets/terms_checkbox.dart';

class ConsentGateScreen extends ConsumerStatefulWidget {
  const ConsentGateScreen({super.key});

  @override
  ConsumerState<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends ConsumerState<ConsentGateScreen> {
  bool _accepted = false;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cluvoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Agree to our policies'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please review and agree to our policies before continuing.',
                style: TextStyle(
                  color: context.cluvoTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TermsCheckbox(
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: context.cluvoErrorText, fontSize: 13),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _accepted && !_submitting ? _onAccept : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I Agree & Continue'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: context.cluvoTextSecondary,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => showLegalDialog(
                                context,
                                title: 'Privacy Policy',
                                sections: privacyPolicySections,
                              ),
                      ),
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => showLegalDialog(
                                context,
                                title: 'Terms of Service',
                                sections: termsSections,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAccept() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(consentProvider.notifier).record(source: 'mobile');
    if (!mounted) return;
    if (ok) {
      context.go('/home');
    } else {
      setState(() {
        _submitting = false;
        _error = 'Could not record consent. Please try again.';
      });
    }
  }
}
