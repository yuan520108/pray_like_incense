import 'package:dio/dio.dart';

abstract interface class SocialRepository {
  Future<List<SocialUser>> searchUsers(String query);

  Future<void> sendFriendInvitation(String targetUserId);

  Future<List<FriendInvitation>> getIncomingInvitations();

  Future<List<SocialUser>> getFriends();

  Future<void> respondToInvitation(String invitationId, {required bool accept});

  Future<NotificationPage> getNotifications({
    String? cursor,
    int pageSize = 50,
    bool unreadOnly = false,
  });

  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead();
}

class SocialService implements SocialRepository {
  final Dio _dio;

  SocialService(this._dio);

  @override
  Future<List<SocialUser>> searchUsers(String query) async {
    try {
      final response = await _dio.post(
        'v1/friends/search',
        data: {'query': query, 'size': 50},
      );
      final data = _map(
        _map(response.data, 'friend search response')['data'],
        'data',
      );
      return _items(data, 'friend search').map(SocialUser.fromJson).toList();
    } on DioException catch (error) {
      throw _apiError('Failed to search users', error);
    }
  }

  @override
  Future<void> sendFriendInvitation(String targetUserId) async {
    try {
      await _dio.post(
        'v1/friends/invitations',
        data: {'targetUserId': targetUserId},
      );
    } on DioException catch (error) {
      throw _apiError('Failed to send friend request', error);
    }
  }

  @override
  Future<List<FriendInvitation>> getIncomingInvitations() async {
    try {
      final response = await _dio.post(
        'v1/friends/invitations/query',
        data: {
          'fields': [
            'avatarUrl',
            'createdAt',
            'displayName',
            'incoming',
            'invitationId',
            'userId',
          ],
          'pagination': {'page': 1, 'pageSize': 50},
        },
      );
      final data = _map(
        _map(response.data, 'friend request response')['data'],
        'data',
      );
      return _items(data, 'friend requests')
          .map(FriendInvitation.fromJson)
          .where((invitation) => invitation.incoming)
          .toList();
    } on DioException catch (error) {
      throw _apiError('Failed to load friend requests', error);
    }
  }

  @override
  Future<List<SocialUser>> getFriends() async {
    try {
      final response = await _dio.post(
        'v1/friends/query',
        data: {
          'fields': ['avatarUrl', 'displayName', 'handle', 'userId'],
          'pagination': {'page': 1, 'pageSize': 50},
        },
      );
      final data = _map(
        _map(response.data, 'friends response')['data'],
        'data',
      );
      return _items(data, 'friends').map(SocialUser.fromJson).toList();
    } on DioException catch (error) {
      throw _apiError('Failed to load friends', error);
    }
  }

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    try {
      await _dio.post(
        'v1/friends/invitations/$invitationId/respond',
        data: {'accept': accept},
      );
    } on DioException catch (error) {
      throw _apiError('Failed to respond to friend request', error);
    }
  }

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    int pageSize = 50,
    bool unreadOnly = false,
  }) async {
    final request = <String, dynamic>{
      'pageSize': pageSize,
      'unreadOnly': unreadOnly,
    };
    if (cursor != null && cursor.isNotEmpty) request['cursor'] = cursor;
    try {
      final response = await _dio.post(
        'v1/notifications/query',
        data: request,
      );
      final body = _map(response.data, 'notifications response');
      final data = _map(body['data'], 'notifications response data');
      final items = _items(data, 'notifications')
          .map(SocialNotification.fromJson)
          .toList(growable: false);
      final nextCursor = data['nextCursor'];
      if (nextCursor != null && nextCursor is! String) {
        throw const FormatException('notifications nextCursor is invalid.');
      }
      final unreadCount = data['unreadCount'];
      if (unreadCount != null && unreadCount is! int) {
        throw const FormatException('notifications unreadCount is invalid.');
      }
      return NotificationPage(
        items: items,
        nextCursor: nextCursor as String?,
        unreadCount: unreadCount as int?,
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load notifications', error);
    }
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _dio.get('v1/notifications/unread-count');
      final data = _map(
        _map(response.data, 'unread notifications response')['data'],
        'data',
      );
      final item = _map(data['item'], 'unread notifications item');
      final count = item['unreadCount'];
      if (count is! int) throw const FormatException('unreadCount is invalid.');
      return count;
    } on DioException catch (error) {
      throw _apiError('Failed to load unread notification count', error);
    }
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _dio.post('v1/notifications/$notificationId/read', data: {});
    } on DioException catch (error) {
      throw _apiError('Failed to mark notification as read', error);
    }
  }

  @override
  Future<void> markAllNotificationsRead() async {
    try {
      await _dio.post<void>('v1/notifications/read-all', data: {});
    } on DioException catch (error) {
      throw _apiError('Failed to mark all notifications as read', error);
    }
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String field) {
    final items = data['items'];
    if (items is! List) throw FormatException('$field items must be an array');
    return items.map((item) => _map(item, '$field item')).toList();
  }

  Map<String, dynamic> _map(dynamic value, String field) {
    if (value is! Map) throw FormatException('$field must be an object');
    return Map<String, dynamic>.from(value);
  }

  Exception _apiError(String action, DioException error) {
    if (error.response?.statusCode != null) {
      return Exception('$action (HTTP ${error.response!.statusCode}).');
    }
    return Exception('$action: ${error.message ?? error.type.name}');
  }
}

class NotificationPage {
  final List<SocialNotification> items;
  final String? nextCursor;
  final int? unreadCount;

  const NotificationPage({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });
}

class SocialUser {
  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final String relation;

  const SocialUser({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.relation,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    userId: _string(json, 'userId'),
    displayName: _string(json, 'displayName'),
    handle: json['handle'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    relation: json['relation'] as String? ?? 'none',
  );
}

class FriendInvitation {
  final String invitationId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool incoming;

  const FriendInvitation({
    required this.invitationId,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.incoming,
  });

  factory FriendInvitation.fromJson(Map<String, dynamic> json) =>
      FriendInvitation(
        invitationId: _string(json, 'invitationId'),
        userId: _string(json, 'userId'),
        displayName: _string(json, 'displayName'),
        avatarUrl: json['avatarUrl'] as String?,
        incoming: json['incoming'] == true,
      );
}

class SocialNotification {
  final String notificationId;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  const SocialNotification({
    required this.notificationId,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  factory SocialNotification.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(_string(json, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException('Notification createdAt date is invalid.');
    }
    final actor = json['actorName'] as String?;
    final type = _string(json, 'notificationType');
    return SocialNotification(
      notificationId: _string(json, 'notificationId'),
      message: actor == null || actor.isEmpty ? type : '$actor · $type',
      notificationType: type,
      isRead: json['isRead'] == true,
      createdAt: createdAt,
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is invalid');
  return value;
}
