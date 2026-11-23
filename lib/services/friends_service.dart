import 'package:dio/dio.dart';

class FriendsService {
  final Dio _dio;

  FriendsService(this._dio);

  Future<List<FriendSearchResult>> searchUsers({
    required String query,
    int size = 20,
  }) async {
    try {
      final response = await _dio.post(
        'v1/friends/search',
        data: {'query': query, 'size': size},
      );
      final body = _asMap(response.data, 'friend search response');
      final data = _asMap(body['data'], 'friend search response data');
      final items = data['items'];
      if (items is! List) {
        throw const FormatException(
          'Friend search response data.items must be a list.',
        );
      }
      return items
          .map(
            (item) =>
                FriendSearchResult.fromJson(_asMap(item, 'search result')),
          )
          .toList(growable: true);
    } on DioException catch (error) {
      throw _apiError('Failed to search users', error);
    }
  }

  Future<FriendInvitationResult> sendInvitation({
    required String targetUserId,
    String? message,
  }) async {
    final request = <String, dynamic>{'targetUserId': targetUserId};
    if (message != null && message.isNotEmpty) {
      request['message'] = message;
    }
    try {
      final response = await _dio.post('v1/friends/invitations', data: request);
      final body = _asMap(response.data, 'friend invitation response');
      final data = _asMap(body['data'], 'friend invitation response data');
      return FriendInvitationResult.fromJson(
        _asMap(data['item'], 'friend invitation response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to send friend invitation', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return Exception('$action：${body['message']}');
    }
    if (error.response?.statusCode != null) {
      return Exception('$action（HTTP ${error.response!.statusCode}）');
    }
    return Exception('$action：${error.message ?? error.type.name}');
  }
}

class FriendSearchResult {
  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final int? tribeCode;
  final String relation;

  const FriendSearchResult({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.tribeCode,
    required this.relation,
  });

  FriendSearchResult copyWith({String? relation}) {
    return FriendSearchResult(
      userId: userId,
      displayName: displayName,
      handle: handle,
      avatarUrl: avatarUrl,
      tribeCode: tribeCode,
      relation: relation ?? this.relation,
    );
  }

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final avatarUrl = json['avatarUrl'];
    final tribeCode = json['tribeCode'];
    if (handle != null && handle is! String) {
      throw const FormatException('Friend handle has an invalid format.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('Friend avatarUrl has an invalid format.');
    }
    if (tribeCode != null && tribeCode is! int) {
      throw const FormatException('Friend tribeCode has an invalid format.');
    }
    return FriendSearchResult(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
      handle: handle as String?,
      avatarUrl: avatarUrl as String?,
      tribeCode: tribeCode as int?,
      relation: _requiredString(json, 'relation'),
    );
  }
}

class FriendInvitationResult {
  final bool alreadyFriends;
  final bool autoAccepted;

  const FriendInvitationResult({
    required this.alreadyFriends,
    required this.autoAccepted,
  });

  factory FriendInvitationResult.fromJson(Map<String, dynamic> json) {
    final alreadyFriends = json['alreadyFriends'];
    final autoAccepted = json['autoAccepted'];
    if (alreadyFriends is! bool || autoAccepted is! bool) {
      throw const FormatException(
        'Friend invitation response fields have invalid formats.',
      );
    }
    return FriendInvitationResult(
      alreadyFriends: alreadyFriends,
      autoAccepted: autoAccepted,
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
    throw FormatException('Friend field $key has an invalid format.');
  }
  return value;
}
