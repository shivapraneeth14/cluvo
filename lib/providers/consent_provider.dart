import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import 'auth_provider.dart';

/// Tracks whether the signed-in user has a recorded consent row (server-side
/// source of truth via the record-consent edge function). Used by the consent
/// gate after login — in particular for Google-created accounts, whose
/// consent can only be recorded post-OAuth.
class ConsentState {
  final bool checking;
  final bool? consented;
  final String? error;

  const ConsentState({this.checking = false, this.consented, this.error});

  ConsentState copyWith({bool? checking, bool? consented, String? error}) {
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
    state = state.copyWith(checking: true, error: null);
    try {
      final res = await supabase.functions.invoke(
        'record-consent',
        method: HttpMethod.get,
      ).timeout(const Duration(seconds: 15));
      final consented = (res.data as Map<String, dynamic>?)?['consent'] == true;
      state = state.copyWith(checking: false, consented: consented);
      return consented;
    } catch (_) {
      state = const ConsentState(
        checking: false,
        consented: true,
        error: 'Could not check consent status.',
      );
      // Fail-open on network errors to avoid blocking app use in offline
      // mode; the signup-time server checks remain the enforcement point.
      return true;
    }
  }

  /// Records consent server-side for the current user (idempotent).
  Future<bool> record({required String source}) async {
    state = state.copyWith(checking: true, error: null);
    try {
      final res = await supabase.functions.invoke(
        'record-consent',
        method: HttpMethod.post,
        body: {'source': source},
      ).timeout(const Duration(seconds: 15));
      final ok = (res.data as Map<String, dynamic>?)?['consent'] == true;
      state = state.copyWith(checking: false, consented: ok);
      return ok;
    } catch (_) {
      state = const ConsentState(
        checking: false,
        consented: false,
        error: 'Could not record consent. Check your connection.',
      );
      return false;
    }
  }

  /// Call after signing out so the next session re-checks.
  void reset() {
    state = const ConsentState();
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>(
  (ref) {
    final notifier = ConsentNotifier();
    ref.listen(authProvider, (prev, next) {
      if (prev?.session != null && next.session == null) {
        notifier.reset();
      }
    });
    return notifier;
  },
);
