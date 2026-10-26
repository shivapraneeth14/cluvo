import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import 'auth_provider.dart';

/// Tracks whether the signed-in user has accepted the current policy version
/// (server-side source of truth via the record-consent edge function).
class ConsentState {
  final bool checking;
  final bool? consented; // has any consent row
  final bool? upToDate; // accepted current CONSENT_VERSION
  final String? error;

  const ConsentState({
    this.checking = false,
    this.consented,
    this.upToDate,
    this.error,
  });

  ConsentState copyWith({
    bool? checking,
    bool? consented,
    bool? upToDate,
    String? error,
  }) {
    return ConsentState(
      checking: checking ?? this.checking,
      consented: consented ?? this.consented,
      upToDate: upToDate ?? this.upToDate,
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
      state = const ConsentState(consented: true, upToDate: true);
      return true;
    }
    // Ignore re-entrant calls while a check is already in flight.
    if (state.checking) return state.upToDate == true;

    state = state.copyWith(checking: true, error: null);
    try {
      final res = await supabase.functions
          .invoke('record-consent', method: HttpMethod.get)
          .timeout(const Duration(seconds: 15));
      final data = res.data as Map<String, dynamic>?;
      final consented = data?['consent'] == true;
      final upToDate = data?['upToDate'] == true;
      state = ConsentState(checking: false, consented: consented, upToDate: upToDate);
      return upToDate;
    } catch (_) {
      // Fail closed: don't assume up to date
      state = ConsentState(
        checking: false,
        consented: state.consented,
        upToDate: state.upToDate,
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
      state = ConsentState(checking: false, consented: ok, upToDate: ok);
      return ok;
    } catch (_) {
      state = const ConsentState(
        checking: false,
        consented: false,
        upToDate: false,
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
