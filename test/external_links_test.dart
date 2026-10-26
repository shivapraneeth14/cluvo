import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/external_links.dart';

void main() {
  group('isSafeExternalUrl', () {
    test('allows mailto only when allowMailto is true', () {
      final uri = Uri.parse('mailto:supp.cluvo@gmail.com?subject=Cluvo%20Support');
      expect(isSafeExternalUrl(uri, allowMailto: true), isTrue);
      expect(isSafeExternalUrl(uri), isFalse);
    });

    test('allows http and https with a host', () {
      expect(isSafeExternalUrl(Uri.parse('https://example.com')), isTrue);
      expect(isSafeExternalUrl(Uri.parse('http://example.com')), isTrue);
    });

    test('rejects http(s) with an empty host', () {
      expect(isSafeExternalUrl(Uri.parse('https://')), isFalse);
    });

    test('rejects other schemes and unsafe URIs', () {
      expect(isSafeExternalUrl(Uri.parse('tel:+1234567890')), isFalse);
      expect(isSafeExternalUrl(Uri.parse('intent://foo#Intent')), isFalse);
      expect(isSafeExternalUrl(Uri.parse('myapp://open')), isFalse);
      expect(isSafeExternalUrl(Uri.parse('not a url')), isFalse);
    });
  });
}
