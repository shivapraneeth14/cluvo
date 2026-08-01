import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

final _cloudName = AppConfig.cloudinaryCloudName;
final _uploadPreset = AppConfig.cloudinaryUploadPreset;
const _maxFileSize = 10 * 1024 * 1024; // 10 MB

Future<String> uploadToCloudinary(XFile image) async {
  final bytes = await image.readAsBytes();
  if (bytes.length > _maxFileSize) {
    throw Exception('File is too large. Maximum size is 10 MB.');
  }

  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
  final request = http.MultipartRequest('POST', uri)
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name))
    ..fields['upload_preset'] = _uploadPreset;

  final response = await request.send().timeout(const Duration(seconds: 30));
  final body = await response.stream.bytesToString();
  final data = jsonDecode(body) as Map<String, dynamic>;

  if (response.statusCode != 200) {
    throw Exception(data['error']['message'] ?? 'Upload failed');
  }

  return data['secure_url'] as String;
}
