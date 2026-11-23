import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  static const int maxImageBytes = 10 * 1024 * 1024;
  final Dio _dio;

  MediaService(this._dio);

  Future<UploadedImage> uploadImage(
    XFile file, {
    required String purpose,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw const FormatException(
        'Image size must be greater than 0 and no more than 10 MiB.',
      );
    }
    final pathName = file.path.replaceAll('\\', '/').split('/').last;
    final fileName = file.name.isNotEmpty
        ? file.name
        : pathName.isNotEmpty
        ? pathName
        : 'witness.jpg';

    try {
      final response = await _dio.post(
        'v1/media/images',
        data: {
          'contentBase64': base64Encode(bytes),
          'fileName': fileName,
          'purpose': purpose,
        },
      );
      final body = _asMap(response.data, 'image upload response');
      final data = _asMap(body['data'], 'image upload response data');
      return UploadedImage.fromJson(
        _asMap(data['item'], 'image upload response item'),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        throw Exception('Image upload failed: ${body['message']}');
      }
      if (error.response?.statusCode != null) {
        throw Exception(
          'Image upload failed (HTTP ${error.response!.statusCode}).',
        );
      }
      throw Exception(
        'Image upload failed: ${error.message ?? error.type.name}',
      );
    }
  }
}

class UploadedImage {
  final String mediaId;
  final String url;
  final String? thumbnailUrl;
  final int byteSize;
  final int width;
  final int height;

  const UploadedImage({
    required this.mediaId,
    required this.url,
    required this.thumbnailUrl,
    required this.byteSize,
    required this.width,
    required this.height,
  });

  factory UploadedImage.fromJson(Map<String, dynamic> json) {
    final thumbnailUrl = json['thumbnailUrl'];
    if (thumbnailUrl != null && thumbnailUrl is! String) {
      throw const FormatException('Image thumbnailUrl has an invalid format.');
    }
    return UploadedImage(
      mediaId: _requiredString(json, 'mediaId'),
      url: _requiredString(json, 'url'),
      thumbnailUrl: thumbnailUrl as String?,
      byteSize: _requiredInt(json, 'byteSize'),
      width: _requiredInt(json, 'width'),
      height: _requiredInt(json, 'height'),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}
