import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

final String supabaseUrl = AppConfig.supabaseUrl;
final String supabaseAnonKey = AppConfig.supabaseAnonKey;

final supabase = Supabase.instance.client;

/// Clears ONLY this device's session before an OAuth redirect.
///
/// OAuth does not implicitly sign out an existing session, so without this a
/// previous user can survive the round-trip and briefly mis-route the app.
/// [SignOutScope.local] leaves the user's other devices signed in.
///
/// Best-effort: any failure (no session, storage already empty) must never
/// block the OAuth attempt, so errors are swallowed.
Future<void> clearLocalSessionForOAuth() async {
  try {
    await supabase.auth.signOut(scope: SignOutScope.local);
  } catch (_) {
    // Nothing to clear — safe to continue to OAuth.
  }
}
