import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import 'profile_provider.dart';
import 'community_provider.dart';
import 'notification_provider.dart';
import 'wishlist_provider.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final Session? session;
  final bool usernameAvailable;
  final bool isRecovery;
  final bool checkingUsername;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.session,
    this.usernameAvailable = true,
    this.isRecovery = false,
    this.checkingUsername = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    Session? session,
    bool? usernameAvailable,
    bool? isRecovery,
    bool? checkingUsername,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSession = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      session: clearSession ? null : session ?? this.session,
      usernameAvailable: usernameAvailable ?? this.usernameAvailable,
      isRecovery: clearSession ? false : isRecovery ?? this.isRecovery,
      checkingUsername: checkingUsername ?? this.checkingUsername,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription? _authSub;
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    try {
      _init();
      _listenAuthChanges();
    } catch (_) {
      // Auth initialization failed — state remains empty, user sees login
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _init() {
    try {
      state = state.copyWith(session: supabase.auth.currentSession);
    } catch (_) {
      // currentSession unavailable — user stays logged out
    }
  }

  void _listenAuthChanges() {
    try {
      _authSub = supabase.auth.onAuthStateChange.listen((data) {
        try {
          if (data.event == AuthChangeEvent.passwordRecovery) {
            state = state.copyWith(session: supabase.auth.currentSession, isRecovery: true);
          }
          if (data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.initialSession ||
              data.event == AuthChangeEvent.tokenRefreshed) {
            state = state.copyWith(
              session: data.session ?? supabase.auth.currentSession,
            );
          }
          if (data.event == AuthChangeEvent.signedOut) {
            state = state.copyWith(clearSession: true);
            _invalidateDependentProviders();
          }
        } catch (_) {
          // Individual auth event handler failed — ignored
        }
      }, onError: (_) {
        // Stream error — subscription terminated; auth changes stop being detected
      });
    } catch (_) {
      // Failed to subscribe to auth changes — app continues without realtime auth sync
    }
  }

  void _invalidateDependentProviders() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(myCommunitiesProvider);
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(wishlistProvider);
  }

  void setError(String message) {
    state = state.copyWith(error: message, clearSuccess: true);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }

  Future<void> checkSession() async {
    try {
      state = state.copyWith(session: supabase.auth.currentSession);
    } catch (_) {
      state = state.copyWith(clearSession: true);
    }
  }

  Future<bool> checkUsername(String username) async {
    state = state.copyWith(checkingUsername: true);
    try {
      final response = await supabase.functions.invoke(
        'check-username',
        body: {'username': username.trim()},
      ).timeout(const Duration(seconds: 10));
      final available = response.data['available'] as bool;
      state = state.copyWith(checkingUsername: false, usernameAvailable: available);
      return available;
    } on FunctionException {
      state = state.copyWith(
        checkingUsername: false,
        usernameAvailable: false,
        error: 'Could not check username right now. Please try again.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        checkingUsername: false,
        usernameAvailable: false,
        error: 'Could not verify username. Check your connection.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await supabase.auth.signOut().timeout(const Duration(seconds: 10));
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyAuthError(e.message));
      return;
    } on TimeoutException {
      // API hung — still clear local state
    } catch (_) {
      // Network error — still clear local state
    }
    state = state.copyWith(isLoading: false, clearSession: true);
  }

  String _friendlyAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please confirm your email address.';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    return message;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
