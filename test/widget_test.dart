import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/config.dart';

void main() {
  test(
    'fail-fast: ensureConfigured refuses to start when no dart-defines were '
    'passed; passes when defines are present',
    () {
      if (AppConfig.supabaseUrl.isEmpty) {
        // Running without --dart-define: the app must refuse to start.
        expect(AppConfig.supabaseUrl, isEmpty);
        expect(AppConfig.supabaseAnonKey, isEmpty);
        expect(AppConfig.cloudinaryCloudName, isEmpty);
        expect(AppConfig.cloudinaryUploadPreset, isEmpty);
        expect(AppConfig.missingRequired(), isNotEmpty);
        expect(AppConfig.ensureConfigured, throwsStateError);
      } else {
        // Running with --dart-define (e.g. CI or a documented build
        // command): configuration is complete and startup proceeds.
        expect(AppConfig.supabaseUrl, isNotEmpty);
        expect(AppConfig.supabaseAnonKey, isNotEmpty);
        expect(AppConfig.cloudinaryCloudName, isNotEmpty);
        expect(AppConfig.cloudinaryUploadPreset, isNotEmpty);
        expect(AppConfig.missingRequired(), isEmpty);
        expect(AppConfig.ensureConfigured, returnsNormally);
      }
    },
  );

  test('share URL builder produces deep link', () {
    expect(buildShareUrl('event', 'abc123'), 'cluvo:///event/abc123');
  });
}
