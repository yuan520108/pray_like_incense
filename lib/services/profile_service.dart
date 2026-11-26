import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final Dio _dio;

  ProfileService(this._dio);

  Future<String> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Avatar must be between 1 byte and 5 MB.');
    }
    try {
      final response = await _dio.post(
        'auth/profile/avatar',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: file.name.isEmpty ? 'avatar.jpg' : file.name,
          ),
          'avatar_url': '',
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      final body = response.data;
      final dynamic url = body is String
          ? body
          : body is Map
          ? (body['profile'] is Map ? body['profile']['avatar_url'] : null) ??
                body['avatar_url'] ??
                (body['data'] is Map ? body['data']['avatar_url'] : null)
          : null;
      if (url is! String || url.trim().isEmpty) {
        throw const FormatException(
          'The server did not return the saved avatar URL.',
        );
      }
      return url;
    } on DioException catch (error) {
      throw _apiError('Failed to update avatar', error);
    }
  }

  Future<ProfileInfo> getMyProfile() async {
    try {
      final response = await _dio.get('v1/profiles/me');
      final body = _asMap(response.data, 'profile response');
      final data = _asMap(body['data'], 'profile response data');
      return ProfileInfo.fromJson(
        _asMap(data['item'], 'profile response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load profile', error);
    }
  }

  Future<ProfileInfo> updateTribe(int tribeCode) async {
    try {
      final response = await _dio.post(
        'v1/profiles/me/tribe',
        data: {'tribeCode': tribeCode},
      );
      final body = _asMap(response.data, 'tribe update response');
      final data = _asMap(body['data'], 'tribe update response data');
      return ProfileInfo.fromJson(
        _asMap(data['item'], 'tribe update response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to update tribe', error);
    }
  }

  Future<List<TribeInfo>> getTribes() async {
    try {
      final response = await _dio.get('v1/tribes');
      final body = _asMap(response.data, 'tribes response');
      final data = _asMap(body['data'], 'tribes response data');
      final items = data['items'];
      if (items is! List) {
        throw const FormatException('Tribes response items must be a list.');
      }
      return items
          .map(
            (item) => TribeInfo.fromJson(_asMap(item, 'tribe response item')),
          )
          .toList();
    } on DioException catch (error) {
      throw _apiError('Failed to load tribes', error);
    }
  }

  Future<TribeInfo> getTribe(int tribeCode) async {
    try {
      final response = await _dio.get('v1/tribes/$tribeCode');
      final body = _asMap(response.data, 'tribe response');
      final data = _asMap(body['data'], 'tribe response data');
      return TribeInfo.fromJson(_asMap(data['item'], 'tribe response item'));
    } on DioException catch (error) {
      throw _apiError('Failed to load tribe', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final statusCode = error.response?.statusCode;
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return Exception('$action: ${body['message']}');
    }
    if (statusCode != null) return Exception('$action (HTTP $statusCode).');
    return Exception('$action: ${error.message ?? error.type.name}');
  }
}

class ProfileInfo {
  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final int? tribeCode;

  const ProfileInfo({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.tribeCode,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final avatarUrl = json['avatarUrl'];
    final tribeCode = json['tribeCode'];
    if (handle != null && handle is! String) {
      throw const FormatException('Profile handle has an invalid format.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('Profile avatarUrl has an invalid format.');
    }
    if (tribeCode != null && tribeCode is! int) {
      throw const FormatException('Profile tribeCode has an invalid format.');
    }
    return ProfileInfo(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
      handle: handle as String?,
      avatarUrl: avatarUrl as String?,
      tribeCode: tribeCode as int?,
    );
  }
}

class TribeInfo {
  final int tribeCode;
  final String nameEn;
  final String descriptionEn;
  final String badge;
  final String slug;
  final String? imageKey;

  const TribeInfo({
    required this.tribeCode,
    required this.nameEn,
    required this.descriptionEn,
    required this.badge,
    required this.slug,
    required this.imageKey,
  });

  factory TribeInfo.fromJson(Map<String, dynamic> json) {
    final tribeCode = json['tribeCode'];
    final imageKey = json['imageKey'];
    if (tribeCode is! int) {
      throw const FormatException('Tribe code has an invalid format.');
    }
    if (imageKey != null && imageKey is! String) {
      throw const FormatException('Tribe imageKey has an invalid format.');
    }
    return TribeInfo(
      tribeCode: tribeCode,
      nameEn: _requiredString(json, 'nameEn'),
      descriptionEn: _requiredString(json, 'descriptionEn'),
      badge: _requiredString(json, 'badge'),
      slug: _requiredString(json, 'slug'),
      imageKey: imageKey as String?,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}
