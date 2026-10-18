import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import 'auth_provider.dart';

/// Tracks whether the signed-in user has a recorded consent row (server-side
/// source of truth via the record-consent edge function). Consent is captured
/// on the login screen (tick above the Continue with Google button) and
/// recorded server-side right after sign-in, when a session token exists.
///
/// No re-prompting: once a consent row exists for the user it stays valid;
/// policy updates do not force existing users to re-accept.
class ConsentState {
  final bool checking;
  final bool? consented;
  final String? error;

  const ConsentState({
    this.checking = false,
    this.consented,
    this.error,
  });

  ConsentState copyWith({
    bool? checking,
    bool? consented,
    String? error,
  }) {
    return ConsentState(
      checking: checking ?? this.checking,
      consented: consented ?? this.consented,
      error: error ?? this.error,
    );
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier() : super(const ConsentState());

  /// Server-side consent status for the current session.
  Future<bool> check() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      state = const ConsentState(consented: true);
      return true;
    }
    // Ignore re-entrant calls while a check is already in flight.
    if (state.checking) return state.consented == true;

    state = state.copyWith(checking: true, error: null);
    try {
      final res = await supabase.functions
          .invoke('record-consent', method: HttpMethod.get)
          .timeout(const Duration(seconds: 15));
      final data = res.data as Map<String, dynamic>?;
      final consented = data?['consent'] == true;
      state = ConsentState(checking: false, consented: consented);
      return consented;
    } catch (_) {
      // Fail closed: consent stays unknown (never true) so callers that
      // depend on it do not assume agreement that was never confirmed.
      state = ConsentState(
        checking: false,
        consented: state.consented,
        error: 'Could not verify consent status. Check your connection.',
      );
      return false;
    }
  }

  /// Records consent server-side for the current user (idempotent).
  Future<bool> record({required String source}) async {
    state = state.copyWith(checking: true, error: null);
    try {
      final res = await supabase.functions
          .invoke(
            'record-consent',
            method: HttpMethod.post,
            body: {'source': source},
          )
          .timeout(const Duration(seconds: 15));
      final data = res.data as Map<String, dynamic>?;
      final ok = data?['consent'] == true;
      state = ConsentState(checking: false, consented: ok);
      return ok;
    } catch (_) {
      state = const ConsentState(
        checking: false,
        consented: false,
        error: 'Could not record consent. Please try again.',
      );
      return false;
    }
  }

  /// Call after signing out so the next session re-checks.
  void reset() {
    state = const ConsentState();
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((
  ref,
) {
  final notifier = ConsentNotifier();
  ref.listen(authProvider, (prev, next) {
    if (prev?.session != null && next.session == null) {
      notifier.reset();
    }
  });
  return notifier;
});
