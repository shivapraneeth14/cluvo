import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config.dart';

void main() {
  test('config defaults are set for web/test builds', () {
    expect(AppConfig.supabaseUrl, isNotEmpty);
    expect(AppConfig.supabaseAnonKey, isNotEmpty);
    expect(AppConfig.razorpayKeyId, startsWith('rzp_test_'));
    expect(AppConfig.cloudinaryCloudName, isNotEmpty);
  });

  test('share URL builder produces deep link', () {
    expect(buildShareUrl('event', 'abc123'), 'cluvo:///event/abc123');
  });
}
