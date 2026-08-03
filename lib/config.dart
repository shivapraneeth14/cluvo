import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  // Environment values are injected ONLY at build time via --dart-define.
  // There are intentionally NO default values here: a build without explicit
  // defines must refuse to start (see ensureConfigured) rather than silently
  // connecting to any environment. Do not add defaults — this is enforced by
  // CI (scripts/check-env-hygiene.sh) and documented in docs/ENV.md.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');
  static const cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  /// Returns the names of required environment variables that were not
  /// provided at build time.
  static List<String> missingRequired() {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (cloudinaryCloudName.isEmpty) missing.add('CLOUDINARY_CLOUD_NAME');
    if (cloudinaryUploadPreset.isEmpty) {
      missing.add('CLOUDINARY_UPLOAD_PRESET');
    }
    return missing;
  }

  /// Fails fast when required environment values were not provided at build
  /// time. The app refuses to start rather than silently picking an
  /// environment. RAZORPAY_KEY_ID is intentionally optional: payment flows
  /// degrade gracefully when it is absent (see event_detail_screen.dart).
  static void ensureConfigured() {
    final missing = missingRequired();
    if (missing.isEmpty) return;
    throw StateError(
      'Supabase / Cloudinary are not configured. This build was created '
      'without the required --dart-define values: ${missing.join(', ')}. '
      'See docs/ENV.md for the exact build commands. '
      'Refusing to start rather than silently connecting to an environment.',
    );
  }
}

const String appDeepLinkBase = 'cluvo://';

String buildShareUrl(String type, String id) {
  if (kIsWeb) return '${Uri.base.origin}/$type/$id';
  return '$appDeepLinkBase/$type/$id';
}
