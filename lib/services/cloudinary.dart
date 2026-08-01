import 'package:cross_file/cross_file.dart';
import 'cloudinary_io.dart'
    if (dart.library.js_interop) 'cloudinary_web.dart' as impl;

Future<String> uploadToCloudinary(XFile image) => impl.uploadToCloudinary(image);
