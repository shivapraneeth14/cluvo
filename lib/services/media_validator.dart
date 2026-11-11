import 'dart:typed_data';

const int maxImageFileSize = 10 * 1024 * 1024; // 10 MB
const allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

/// Validates image bytes, file size, extension, and magic-byte signature.
/// Throws an [Exception] if validation fails.
void validateImageBytes(Uint8List bytes, {String? filename}) {
  if (bytes.isEmpty) {
    throw Exception('File is empty.');
  }

  if (bytes.length > maxImageFileSize) {
    throw Exception('File is too large. Maximum size is 10 MB.');
  }

  if (filename != null && filename.isNotEmpty) {
    final cleanPath = filename.split('?').first;
    final parts = cleanPath.split('.');
    if (parts.length < 2) {
      throw Exception('File must have a valid extension (.jpg, .jpeg, .png, .webp, .gif).');
    }
    final ext = parts.last.toLowerCase();
    if (!allowedImageExtensions.contains(ext)) {
      throw Exception('Only JPEG, PNG, WebP, and GIF images are allowed.');
    }
  }

  if (!_hasValidImageMagicBytes(bytes)) {
    throw Exception('Invalid image file content. File header does not match allowed image formats.');
  }
}

bool _hasValidImageMagicBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;

  // 1. JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return true;
  }

  // 2. PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return true;
  }

  // 3. WebP: RIFF (bytes 0-3) + WEBP (bytes 8-11)
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }

  // 4. GIF: GIF8 (47 49 46 38)
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61) {
    return true;
  }

  return false;
}

