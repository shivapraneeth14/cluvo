import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the platform secure store
/// (Android EncryptedSharedPreferences / iOS Keychain) instead of plaintext
/// SharedPreferences.
///
/// Used on native platforms only. The web build keeps the supabase_flutter
/// default storage because there is no native keystore there.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: supabasePersistSessionKey)) != null;

  @override
  Future<String?> accessToken() =>
      _storage.read(key: supabasePersistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: supabasePersistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) => _storage.write(
        key: supabasePersistSessionKey,
        value: persistSessionString,
      );
}
