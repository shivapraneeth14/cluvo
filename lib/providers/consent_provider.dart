import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import 'auth_provider.dart';

/// Tracks whether the signed-in user has a recorded consent row (server-side
/// source of truth via the record-consent edge function). Used by the consent
/// gate after login — in particular for Google-created accounts, whose
/// consent can only be recorded post-OAuth.
///
/// Fails closed: if the server cannot be reached and no prior positive consent
/// is known (in memory or cached on disk), consent stays unknown so the gate
/// can block the user. A cached positive consent (keyed per user) lets an
/// already-consented user through while offline.
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

String _consentCacheKey(String userId) => 'consent_ok_$userId';

Future<void> _rememberConsent(String userId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_consentCacheKey(userId), '1');
}

Future<bool> _cachedConsent(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_consentCacheKey(userId)) != null;
  } catch (_) {
    return false;
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
      final consented =
          (res.data as Map<String, dynamic>?)?['consent'] == true;
      state = ConsentState(checking: false, consented: consented);
      if (consented) await _rememberConsent(session.user.id);
      return consented;
    } catch (_) {
      final cached = await _cachedConsent(session.user.id);
      // Fail closed: keep consent unknown (never true) unless a prior positive
      // check is known. Null != true, so the gate stays visible for new users.
      state = ConsentState(
        checking: false,
        consented: cached ? true : state.consented,
        error: 'Could not verify consent status. Check your connection.',
      );
      return state.consented == true;
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
      final ok = (res.data as Map<String, dynamic>?)?['consent'] == true;
      state = ConsentState(checking: false, consented: ok);
      final uid = supabase.auth.currentSession?.user.id;
      if (ok && uid != null) await _rememberConsent(uid);
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