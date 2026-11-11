import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/media_validator.dart';

void main() {
  group('MediaValidator (BUG-006)', () {
    test('accepts valid JPEG bytes with correct extension', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      ]);
      expect(() => validateImageBytes(bytes, filename: 'avatar.jpg'), returnsNormally);
      expect(() => validateImageBytes(bytes, filename: 'photo.JPEG'), returnsNormally);
    });

    test('accepts valid PNG bytes with correct extension', () {
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      ]);
      expect(() => validateImageBytes(bytes, filename: 'image.png'), returnsNormally);
      expect(() => validateImageBytes(bytes, filename: 'image.PNG'), returnsNormally);
    });

    test('accepts valid WebP bytes with correct extension', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x20, 0x00, 0x00, 0x00, // size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(() => validateImageBytes(bytes, filename: 'graphic.webp'), returnsNormally);
    });

    test('accepts valid GIF bytes with correct extension', () {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
      ]);
      expect(() => validateImageBytes(bytes, filename: 'animation.gif'), returnsNormally);
    });

    test('rejects disallowed file extensions (e.g. svg, html, exe)', () {
      final validJpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      ]);
      expect(
        () => validateImageBytes(validJpeg, filename: 'exploit.svg'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Only JPEG, PNG, WebP, and GIF images are allowed'),
        )),
      );
      expect(
        () => validateImageBytes(validJpeg, filename: 'payload.html'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => validateImageBytes(validJpeg, filename: 'malware.exe'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects spoofed files (SVG/HTML content disguised as .png)', () {
      // String bytes: "<svg xmlns=..."
      final spoofedSvg = Uint8List.fromList([
        0x3C, 0x73, 0x76, 0x67, 0x20, 0x78, 0x6D, 0x6C, 0x6E, 0x73, 0x3D, 0x22,
      ]);
      expect(
        () => validateImageBytes(spoofedSvg, filename: 'innocent.png'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Invalid image file content'),
        )),
      );
    });

    test('rejects files exceeding maximum size (10 MB)', () {
      final largeBytes = Uint8List(10 * 1024 * 1024 + 1);
      // Valid PNG header on oversized file
      largeBytes[0] = 0x89;
      largeBytes[1] = 0x50;
      largeBytes[2] = 0x4E;
      largeBytes[3] = 0x47;
      largeBytes[4] = 0x0D;
      largeBytes[5] = 0x0A;
      largeBytes[6] = 0x1A;
      largeBytes[7] = 0x0A;

      expect(
        () => validateImageBytes(largeBytes, filename: 'huge.png'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('File is too large'),
        )),
      );
    });

    test('rejects empty bytes', () {
      expect(
        () => validateImageBytes(Uint8List(0), filename: 'empty.jpg'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('File is empty'),
        )),
      );
    });
  });
}

