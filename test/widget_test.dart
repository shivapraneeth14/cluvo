import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config.dart';

void main() {
  test('fail-fast: throws when SUPABASE dart-defines are not provided', () {
    expect(AppConfig.supabaseUrl, isEmpty);
    expect(AppConfig.supabaseAnonKey, isEmpty);
    expect(AppConfig.ensureConfigured, throwsStateError);
  });

  test('share URL builder produces deep link', () {
    expect(buildShareUrl('event', 'abc123'), 'cluvo:///event/abc123');
  });
}
