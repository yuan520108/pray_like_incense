import 'package:dio/dio.dart';

abstract interface class PostsRepository {
  Future<PostFeedPage> getFeed({
    required String category,
    String? cursor,
    int pageSize = 20,
  });

  Future<PrayerPost> createPost({
    required String content,
    String? title,
    required String category,
    required String privacy,
  });
}

class PostsService implements PostsRepository {
  final Dio _dio;

  PostsService(this._dio);

  @override
  Future<PostFeedPage> getFeed({
    required String category,
    String? cursor,
    int pageSize = 20,
  }) async {
    final request = <String, dynamic>{
      'scope': 'all',
      'mode': 'latest',
      'pageSize': pageSize,
      'category': category,
    };
    if (cursor != null && cursor.isNotEmpty) {
      request['cursor'] = cursor;
    }

    try {
      final response = await _dio.post('v1/posts/feed', data: request);
      return PostFeedPage.fromJson(_asMap(response.data, '動態牆回應'));
    } on DioException catch (error) {
      throw _apiError('載入貼文失敗', error);
    }
  }

  @override
  Future<PrayerPost> createPost({
    required String content,
    String? title,
    required String category,
    required String privacy,
  }) async {
    final request = <String, dynamic>{
      'content': content,
      'category': category,
      'privacy': privacy,
    };
    if (title != null && title.isNotEmpty) {
      request['title'] = title;
    }

    try {
      final response = await _dio.post('v1/posts', data: request);
      final body = _asMap(response.data, '發文回應');
      final data = _asMap(body['data'], '發文回應 data');
      return PrayerPost.fromJson(_asMap(data['item'], '發文回應 item'));
    } on DioException catch (error) {
      throw _apiError('發布貼文失敗', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final response = error.response;
    final body = response?.data;
    if (body is Map && body['message'] is String) {
      return Exception('$action：${body['message']}');
    }
    if (response?.statusCode != null) {
      return Exception('$action（HTTP ${response!.statusCode}）');
    }
    return Exception('$action：${error.message ?? error.type.name}');
  }
}

class PostFeedPage {
  final List<PrayerPost> items;
  final String? nextCursor;

  const PostFeedPage({required this.items, required this.nextCursor});

  factory PostFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], '動態牆回應 data');
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('動態牆回應 data.items 必須是陣列');
    }

    final rawCursor = data['nextCursor'];
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException('動態牆回應 data.nextCursor 格式不正確');
    }

    return PostFeedPage(
      items: rawItems
          .map((item) => PrayerPost.fromJson(_asMap(item, '動態牆貼文')))
          .toList(growable: false),
      nextCursor: rawCursor as String?,
    );
  }
}

class PrayerPost {
  final String postId;
  final String userId;
  final PrayerPostAuthor? author;
  final String? title;
  final String content;
  final String? category;
  final String privacy;
  final DateTime createdAt;
  final int amenCount;
  final int commentCount;
  final bool amened;
  final bool witnessed;

  const PrayerPost({
    required this.postId,
    required this.userId,
    required this.author,
    required this.title,
    required this.content,
    required this.category,
    required this.privacy,
    required this.createdAt,
    required this.amenCount,
    required this.commentCount,
    required this.amened,
    required this.witnessed,
  });

  factory PrayerPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    if (author != null && author is! Map) {
      throw const FormatException('貼文 author 格式不正確');
    }

    final rawTitle = json['title'];
    if (rawTitle != null && rawTitle is! String) {
      throw const FormatException('貼文 title 格式不正確');
    }
    final rawCategory = json['category'];
    if (rawCategory != null && rawCategory is! String) {
      throw const FormatException('貼文 category 格式不正確');
    }

    final createdAtValue = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('貼文 createdAt 日期格式不正確');
    }

    return PrayerPost(
      postId: _requiredString(json, 'postId'),
      userId: _requiredString(json, 'userId'),
      author: author == null
          ? null
          : PrayerPostAuthor.fromJson(Map<String, dynamic>.from(author)),
      title: rawTitle as String?,
      content: _requiredString(json, 'content'),
      category: rawCategory as String?,
      privacy: _requiredString(json, 'privacy'),
      createdAt: createdAt,
      amenCount: _requiredInt(json, 'amenCount'),
      commentCount: _requiredInt(json, 'commentCount'),
      amened: _requiredBool(json, 'amened'),
      witnessed: _requiredBool(json, 'witnessed'),
    );
  }
}

class PrayerPostAuthor {
  final String userId;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final int? tribeCode;

  const PrayerPostAuthor({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.tribeCode,
  });

  factory PrayerPostAuthor.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final avatarUrl = json['avatarUrl'];
    final tribeCode = json['tribeCode'];
    if (handle != null && handle is! String) {
      throw const FormatException('貼文作者 handle 格式不正確');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('貼文作者 avatarUrl 格式不正確');
    }
    if (tribeCode != null && tribeCode is! int) {
      throw const FormatException('貼文作者 tribeCode 格式不正確');
    }

    return PrayerPostAuthor(
      userId: _requiredString(json, 'userId'),
      displayName: _requiredString(json, 'displayName'),
      handle: handle as String?,
      avatarUrl: avatarUrl as String?,
      tribeCode: tribeCode as int?,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is! Map) {
    throw FormatException('$field 必須是物件');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('貼文欄位 $key 格式不正確');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('貼文欄位 $key 格式不正確');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('貼文欄位 $key 格式不正確');
  }
  return value;
}
