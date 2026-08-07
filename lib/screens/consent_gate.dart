import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/consent_provider.dart';
import '../widgets/terms_checkbox.dart';
import '../theme.dart';

/// Full-screen gate shown only right after a brand-new account is created
/// via Google OAuth (signup moment) — returning logins go straight to the
/// app with no intermediate page. Consent is recorded server-side once.
class ConsentGate extends ConsumerStatefulWidget {
  final Widget child;

  const ConsentGate({super.key, required this.child});

  @override
  ConsumerState<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<ConsentGate> {
  bool _agreed = false;

  bool _isNewAccount(Session session) {
    final user = session.user;
    final createdAt = DateTime.tryParse(user.createdAt);
    final lastSignInAt = user.lastSignInAt == null
        ? null
        : DateTime.tryParse(user.lastSignInAt!);
    if (createdAt == null || lastSignInAt == null) return false;
    // A just-created OAuth account has created_at == last_sign_in_at;
    // a returning account always has created_at strictly older.
    return lastSignInAt.difference(createdAt).inSeconds.abs() < 120;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).session;
    final consentState = ref.watch(consentProvider);

    if (session == null ||
        consentState.consented == true ||
        !_isNewAccount(session)) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'CLUVO',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: CluvoTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Before you continue',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review and agree to our policies. You can read the full '
                'text by tapping the underlined links below.',
                style: TextStyle(
                  color: context.cluvoTextSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              TermsCheckbox(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v),
              ),
              if (consentState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  consentState.error!,
                  style: TextStyle(color: context.cluvoErrorText, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _agreed && !consentState.checking
                      ? () async {
                          final ok = await ref
                              .read(consentProvider.notifier)
                              .record(source: 'mobile');
                          if (ok && context.mounted) {
                            setState(() => _agreed = false);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Could not record consent. Please try again.'),
                              ),
                            );
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: CluvoTheme.primary,
                    disabledBackgroundColor:
                        CluvoTheme.primary.withValues(alpha: 0.4),
                  ),
                  child: consentState.checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('I Agree & Continue'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(authProvider.notifier).signOut(),
                  child: Text(
                    'Sign out',
                    style: TextStyle(color: context.cluvoTextSecondary),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
