import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://ofvfasdgdwkehdcjugnf.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mdmZhc2RnZHdrZWhkY2p1Z25mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU1OTkxNDcsImV4cCI6MjEwMTE3NTE0N30.oaxiWOFClGzO1WqBihmLoZV69soVpfMv6gtUMnMakxY');
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: 'rzp_test_THqWNZqOZGQZOu');
  static const cloudinaryCloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: 'djz0pypu1');
  static const cloudinaryUploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: 'cluvo_preset');
}

const String appDeepLinkBase = 'cluvo://';

String buildShareUrl(String type, String id) {
  if (kIsWeb) return '${Uri.base.origin}/$type/$id';
  return '$appDeepLinkBase/$type/$id';
}
