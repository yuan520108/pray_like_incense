import 'package:dio/dio.dart';

abstract interface class PostsRepository {
  Future<PostFeedPage> getFeed({
    String? category,
    String? cursor,
    int pageSize = 25,
  });

  Future<PrayerPost> createPost({
    required String content,
    String? title,
    required String category,
    required String privacy,
  });

  Future<PrayerPost> updatePost({
    required String postId,
    required String? title,
    required String content,
  });

  Future<AmenResult> toggleAmen({
    required String targetId,
    required String targetType,
  });

  Future<PostComment> createComment({
    required String postId,
    required String content,
  });

  Future<CommentFeedPage> getComments({
    required String postId,
    String? cursor,
    int pageSize = 25,
  });
}

class PostsService implements PostsRepository {
  final Dio _dio;

  PostsService(this._dio);

  @override
  Future<PostFeedPage> getFeed({
    String? category,
    String? cursor,
    int pageSize = 25,
  }) async {
    final request = <String, dynamic>{
      'scope': 'all',
      'mode': 'latest',
      'pageSize': pageSize,
    };
    if (category != null && category.isNotEmpty) {
      request['category'] = category;
    }
    if (cursor != null && cursor.isNotEmpty) {
      request['cursor'] = cursor;
    }

    try {
      final response = await _dio.post('v1/posts/feed', data: request);
      return PostFeedPage.fromJson(_asMap(response.data, 'post feed response'));
    } on DioException catch (error) {
      throw _apiError('Failed to load posts', error);
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
      final body = _asMap(response.data, 'create post response');
      final data = _asMap(body['data'], 'create post response data');
      return PrayerPost.fromJson(
        _asMap(data['item'], 'create post response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to publish post', error);
    }
  }

  @override
  Future<PrayerPost> updatePost({
    required String postId,
    required String? title,
    required String content,
  }) async {
    try {
      final response = await _dio.put(
        'v1/posts/$postId',
        data: {'title': title, 'content': content},
      );
      final body = _asMap(response.data, 'edit post response');
      final data = _asMap(body['data'], 'edit post response data');
      return PrayerPost.fromJson(
        _asMap(data['item'], 'edit post response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to edit post', error);
    }
  }

  @override
  Future<AmenResult> toggleAmen({
    required String targetId,
    required String targetType,
  }) async {
    try {
      final response = await _dio.post(
        'v1/posts/amen',
        data: {'targetId': targetId, 'targetType': targetType},
      );
      final body = _asMap(response.data, 'Amen response');
      final data = _asMap(body['data'], 'Amen response data');
      return AmenResult.fromJson(_asMap(data['item'], 'Amen response item'));
    } on DioException catch (error) {
      throw _apiError('Failed to update Amen status', error);
    }
  }

  @override
  Future<PostComment> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        'v1/posts/$postId/comments',
        data: {'content': content},
      );
      final body = _asMap(response.data, 'comment response');
      final data = _asMap(body['data'], 'comment response data');
      return PostComment.fromJson(
        _asMap(data['item'], 'comment response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to send comment', error);
    }
  }

  @override
  Future<CommentFeedPage> getComments({
    required String postId,
    String? cursor,
    int pageSize = 25,
  }) async {
    final request = <String, dynamic>{'pageSize': pageSize};
    if (cursor != null && cursor.isNotEmpty) {
      request['cursor'] = cursor;
    }

    try {
      final response = await _dio.post(
        'v1/posts/$postId/comments/query',
        data: request,
      );
      return CommentFeedPage.fromJson(
        _asMap(response.data, 'comment list response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load comments', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final response = error.response;
    final body = response?.data;
    if (body is Map && body['message'] is String) {
      return Exception('$action: ${body['message']}');
    }
    if (response?.statusCode != null) {
      return Exception('$action (HTTP ${response!.statusCode})');
    }
    return Exception('$action: ${error.message ?? error.type.name}');
  }
}

class PostFeedPage {
  final List<PrayerPost> items;
  final String? nextCursor;

  const PostFeedPage({required this.items, required this.nextCursor});

  factory PostFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'post feed response data');
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Post feed response data.items must be a list.',
      );
    }

    final rawCursor = data['nextCursor'];
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException(
        'Post feed response data.nextCursor has an invalid format.',
      );
    }

    return PostFeedPage(
      items: rawItems
          .map((item) => PrayerPost.fromJson(_asMap(item, 'post feed item')))
          .toList(growable: false),
      nextCursor: rawCursor as String?,
    );
  }
}

class AmenResult {
  final int amenCount;
  final bool amened;

  const AmenResult({required this.amenCount, required this.amened});

  factory AmenResult.fromJson(Map<String, dynamic> json) {
    return AmenResult(
      amenCount: _requiredInt(json, 'amenCount'),
      amened: _requiredBool(json, 'amened'),
    );
  }
}

class PostComment {
  final String commentId;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final PrayerPostAuthor? author;
  final int amenCount;
  final bool amened;

  const PostComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.author,
    required this.amenCount,
    required this.amened,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    if (rawAuthor != null && rawAuthor is! Map) {
      throw const FormatException('Comment author has an invalid format.');
    }

    return PostComment(
      commentId: _requiredString(json, 'commentId'),
      postId: _requiredString(json, 'postId'),
      userId: _requiredString(json, 'userId'),
      content: _requiredString(json, 'content'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      author: rawAuthor == null
          ? null
          : PrayerPostAuthor.fromJson(Map<String, dynamic>.from(rawAuthor)),
      amenCount: _requiredInt(json, 'amenCount'),
      amened: _requiredBool(json, 'amened'),
    );
  }
}

class CommentFeedPage {
  final List<PostComment> items;
  final String? nextCursor;

  const CommentFeedPage({required this.items, required this.nextCursor});

  factory CommentFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'comment list response data');
    final rawItems = data['items'];
    final rawCursor = data['nextCursor'];
    if (rawItems is! List) {
      throw const FormatException(
        'Comment list response data.items must be a list.',
      );
    }
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException(
        'Comment list response data.nextCursor has an invalid format.',
      );
    }

    return CommentFeedPage(
      items: rawItems
          .map(
            (item) => PostComment.fromJson(_asMap(item, 'comment list item')),
          )
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
      throw const FormatException('Post author has an invalid format.');
    }

    final rawTitle = json['title'];
    if (rawTitle != null && rawTitle is! String) {
      throw const FormatException('Post title has an invalid format.');
    }
    final rawCategory = json['category'];
    if (rawCategory != null && rawCategory is! String) {
      throw const FormatException('Post category has an invalid format.');
    }

    final createdAtValue = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('Post createdAt date has an invalid format.');
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
      throw const FormatException('Post author handle has an invalid format.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException(
        'Post author avatarUrl has an invalid format.',
      );
    }
    if (tribeCode != null && tribeCode is! int) {
      throw const FormatException(
        'Post author tribeCode has an invalid format.',
      );
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
    throw FormatException('$field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Post field $key has an invalid format.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Field $key date has an invalid format.');
  }
  return parsed;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Post field $key has an invalid format.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Post field $key has an invalid format.');
  }
  return value;
}
