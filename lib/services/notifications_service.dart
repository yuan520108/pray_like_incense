import 'package:dio/dio.dart';

class NotificationsService {
  final Dio _dio;

  NotificationsService(this._dio);

  Future<NotificationFeedPage> getFeed({
    String? cursor,
    int pageSize = 25,
    bool? unreadOnly,
  }) async {
    final request = <String, dynamic>{'pageSize': pageSize};
    if (cursor != null && cursor.isNotEmpty) {
      request['cursor'] = cursor;
    }
    if (unreadOnly != null) {
      request['unreadOnly'] = unreadOnly;
    }

    try {
      final response = await _dio.post('v1/notifications/query', data: request);
      return NotificationFeedPage.fromJson(
        _asMap(response.data, 'notification list response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load notifications', error);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('v1/notifications/unread-count');
      final body = _asMap(response.data, 'unread notification response');
      final data = _asMap(body['data'], 'unread notification response data');
      final item = _asMap(data['item'], 'unread notification response item');
      return _requiredInt(item, 'unreadCount');
    } on DioException catch (error) {
      throw _apiError('Failed to load unread notification count', error);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _dio.post(
        'v1/notifications/$notificationId/read',
        data: <String, dynamic>{},
      );
    } on DioException catch (error) {
      throw _apiError('Failed to mark notification as read', error);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('v1/notifications/read-all', data: <String, dynamic>{});
    } on DioException catch (error) {
      throw _apiError('Failed to mark all notifications as read', error);
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

class NotificationFeedPage {
  final List<NotificationItem> items;
  final String? nextCursor;
  final int unreadCount;

  const NotificationFeedPage({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });

  factory NotificationFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'notification list response data');
    final rawItems = data['items'];
    final rawCursor = data['nextCursor'];
    if (rawItems is! List) {
      throw const FormatException(
        'Notification list response data.items must be a list.',
      );
    }
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException(
        'Notification list response data.nextCursor has an invalid format.',
      );
    }

    return NotificationFeedPage(
      items: rawItems
          .map(
            (item) => NotificationItem.fromJson(
              _asMap(item, 'notification list item'),
            ),
          )
          .toList(growable: false),
      nextCursor: rawCursor as String?,
      unreadCount: _requiredInt(data, 'unreadCount'),
    );
  }
}

class NotificationActor {
  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;

  const NotificationActor({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
  });

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
      handle: _nullableString(json, 'handle'),
      avatarUrl: _nullableString(json, 'avatarUrl'),
    );
  }
}

class NotificationItem {
  final String notificationId;
  final String messageKey;
  final String notificationType;
  final String targetId;
  final String targetType;
  final String refId;
  final String refType;
  final String url;
  final String? actorName;
  final NotificationActor? actor;
  final String? postTitle;
  final String? postPreview;
  final bool isRead;
  final int count;
  final DateTime createdAt;

  const NotificationItem({
    required this.notificationId,
    required this.messageKey,
    required this.notificationType,
    required this.targetId,
    required this.targetType,
    required this.refId,
    required this.refType,
    required this.url,
    required this.actorName,
    required this.actor,
    required this.postTitle,
    required this.postPreview,
    required this.isRead,
    required this.count,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawActor = json['actor'];
    if (rawActor != null && rawActor is! Map) {
      throw const FormatException('Notification actor has an invalid format.');
    }
    final createdAt = DateTime.tryParse(_requiredString(json, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException(
        'Notification createdAt date has an invalid format.',
      );
    }

    return NotificationItem(
      notificationId: _requiredString(json, 'notificationId'),
      messageKey: _requiredString(json, 'messageKey'),
      notificationType: _requiredString(json, 'notificationType'),
      targetId: _requiredString(json, 'targetId'),
      targetType: _requiredString(json, 'targetType'),
      refId: _requiredString(json, 'refId'),
      refType: _requiredString(json, 'refType'),
      url: _requiredString(json, 'url'),
      actorName: _nullableString(json, 'actorName'),
      actor: rawActor == null
          ? null
          : NotificationActor.fromJson(Map<String, dynamic>.from(rawActor)),
      postTitle: _nullableString(json, 'postTitle'),
      postPreview: _nullableString(json, 'postPreview'),
      isRead: _requiredBool(json, 'isRead'),
      count: _requiredInt(json, 'count'),
      createdAt: createdAt,
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      notificationId: notificationId,
      messageKey: messageKey,
      notificationType: notificationType,
      targetId: targetId,
      targetType: targetType,
      refId: refId,
      refType: refType,
      url: url,
      actorName: actorName,
      actor: actor,
      postTitle: postTitle,
      postPreview: postPreview,
      isRead: isRead ?? this.isRead,
      count: count,
      createdAt: createdAt,
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

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value as String?;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}
