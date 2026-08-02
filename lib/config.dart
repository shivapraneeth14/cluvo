import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void ensureConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase is not configured. Build with '
        '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        'or run ./scripts/switch-supabase.sh to print the exact command.',
      );
    }
  }

  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: 'rzp_test_THqWNZqOZGQZOu');
  static const cloudinaryCloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'djz0pypu1');
  static const cloudinaryUploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'cluvo_preset');
}

const String appDeepLinkBase = 'cluvo://';

String buildShareUrl(String type, String id) {
  if (kIsWeb) return '${Uri.base.origin}/$type/$id';
  return '$appDeepLinkBase/$type/$id';
}

