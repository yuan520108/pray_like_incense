import 'package:dio/dio.dart';

import 'api_client.dart';

abstract interface class PostsRepository {
  Future<PostFeedPage> getFeed({
    required String category,
    String? cursor,
    int pageSize = 10,
  });

  Future<PrayerPost> createPost({
    required String content,
    String? title,
    required String category,
    required String privacy,
  });

  Future<PostEngagement> amenPost(String postId);

  Future<PostEngagement> amenComment(String commentId);

  Future<PostCommentPage> getComments(String postId, {String? cursor});

  Future<List<PostWitness>> getWitnesses(String postId);

  Future<void> createComment(String postId, String content);

  Future<void> createWitness(String postId, String content);
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
      return PostFeedPage.fromJson(_asMap(response.data, 'feed response'));
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
  Future<PostEngagement> amenPost(String postId) async {
    return _amenTarget(postId, 'post');
  }

  @override
  Future<PostEngagement> amenComment(String commentId) async {
    return _amenTarget(commentId, 'comment');
  }

  Future<PostEngagement> _amenTarget(String targetId, String targetType) async {
    try {
      final response = await _dio.post(
        'v1/posts/amen',
        data: {'targetId': targetId, 'targetType': targetType},
      );
      final body = _asMap(response.data, 'Amen response');
      final data = _asMap(body['data'], 'Amen response data');
      final item = _asMap(data['item'], 'Amen response item');
      return PostEngagement(
        amenCount: _requiredInt(item, 'amenCount'),
        amened: _requiredBool(item, 'amened'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to Amen post', error);
    }
  }

  @override
  Future<PostCommentPage> getComments(String postId, {String? cursor}) async {
    final request = <String, dynamic>{'pageSize': 10};
    if (cursor != null && cursor.isNotEmpty) request['cursor'] = cursor;

    try {
      final response = await _dio.post(
        'v1/posts/$postId/comments/query',
        data: request,
      );
      return PostCommentPage.fromJson(
        _asMap(response.data, 'comments response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load comments', error);
    }
  }

  @override
  Future<void> createComment(String postId, String content) async {
    try {
      await _dio.post('v1/posts/$postId/comments', data: {'content': content});
    } on DioException catch (error) {
      throw _apiError('Failed to post comment', error);
    }
  }

  @override
  Future<List<PostWitness>> getWitnesses(String postId) async {
    try {
      final response = await _dio.post(
        'v1/posts/$postId/witnesses/query',
        options: Options(extra: {ApiClient.omitContentTypeExtraKey: true}),
      );
      final body = _asMap(response.data, 'witnesses response');
      final data = _asMap(body['data'], 'witnesses response data');
      final items = data['items'];
      if (items is! List) {
        throw const FormatException(
          'Witnesses response data.items must be an array.',
        );
      }
      return items
          .map((item) => PostWitness.fromJson(_asMap(item, 'post witness')))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _apiError('Failed to load testimonies', error);
    }
  }

  @override
  Future<void> createWitness(String postId, String content) async {
    try {
      await _dio.post('v1/posts/$postId/witnesses', data: {'content': content});
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw Exception('You have already shared a testimony for this post.');
      }
      throw _apiError('Failed to submit testimony', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final response = error.response;
    if (response?.statusCode != null) {
      return Exception('$action (HTTP ${response!.statusCode}).');
    }
    return Exception('$action: ${error.message ?? error.type.name}');
  }
}

class PostFeedPage {
  final List<PrayerPost> items;
  final String? nextCursor;

  const PostFeedPage({required this.items, required this.nextCursor});

  factory PostFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'feed response data');
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('feed response data.items must be an array');
    }

    final rawCursor = data['nextCursor'];
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException('feed response data.nextCursor is invalid');
    }

    return PostFeedPage(
      items: rawItems
          .map((item) => PrayerPost.fromJson(_asMap(item, 'feed post')))
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

  PrayerPost copyWith({
    int? amenCount,
    int? commentCount,
    bool? amened,
    bool? witnessed,
  }) => PrayerPost(
    postId: postId,
    userId: userId,
    author: author,
    title: title,
    content: content,
    category: category,
    privacy: privacy,
    createdAt: createdAt,
    amenCount: amenCount ?? this.amenCount,
    commentCount: commentCount ?? this.commentCount,
    amened: amened ?? this.amened,
    witnessed: witnessed ?? this.witnessed,
  );

  factory PrayerPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    if (author != null && author is! Map) {
      throw const FormatException('Post author is invalid.');
    }

    final rawTitle = json['title'];
    if (rawTitle != null && rawTitle is! String) {
      throw const FormatException('Post title is invalid.');
    }
    final rawCategory = json['category'];
    if (rawCategory != null && rawCategory is! String) {
      throw const FormatException('Post category is invalid.');
    }

    final createdAtValue = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('Post createdAt date is invalid.');
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

class PostEngagement {
  final int amenCount;
  final bool amened;

  const PostEngagement({required this.amenCount, required this.amened});
}

class PostCommentPage {
  final List<PostComment> items;
  final String? nextCursor;

  const PostCommentPage({required this.items, required this.nextCursor});

  factory PostCommentPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'comments response data');
    final items = data['items'];
    if (items is! List) {
      throw const FormatException(
        'Comments response data.items must be an array',
      );
    }
    final cursor = data['nextCursor'];
    if (cursor != null && cursor is! String) {
      throw const FormatException(
        'Comments response data.nextCursor is invalid',
      );
    }
    return PostCommentPage(
      items: items
          .map((item) => PostComment.fromJson(_asMap(item, 'post comment')))
          .toList(growable: false),
      nextCursor: cursor as String?,
    );
  }
}

class PostComment {
  final String commentId;
  final String content;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final int amenCount;
  final bool amened;

  const PostComment({
    required this.commentId,
    required this.content,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
    required this.amenCount,
    required this.amened,
  });

  PostComment copyWith({int? amenCount, bool? amened}) => PostComment(
    commentId: commentId,
    content: content,
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    createdAt: createdAt,
    amenCount: amenCount ?? this.amenCount,
    amened: amened ?? this.amened,
  );

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    if (author != null && author is! Map) {
      throw const FormatException('Comment author is invalid.');
    }
    final authorMap = author == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(author);
    final avatar = authorMap['avatarUrl'];
    if (avatar != null && avatar is! String) {
      throw const FormatException('Comment author avatarUrl is invalid.');
    }
    final rawDate = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(rawDate);
    if (createdAt == null) {
      throw const FormatException('Comment createdAt date is invalid.');
    }
    return PostComment(
      commentId: _requiredString(json, 'commentId'),
      content: _requiredString(json, 'content'),
      userId: _requiredString(json, 'userId'),
      displayName: authorMap['displayName'] is String
          ? authorMap['displayName'] as String
          : 'Unknown user',
      avatarUrl: avatar as String?,
      createdAt: createdAt,
      amenCount: _requiredInt(json, 'amenCount'),
      amened: _requiredBool(json, 'amened'),
    );
  }
}

class PostWitness {
  final String witnessId;
  final String postId;
  final String userId;
  final String content;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final int amenCount;
  final bool amened;

  const PostWitness({
    required this.witnessId,
    required this.postId,
    required this.userId,
    required this.content,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
    required this.amenCount,
    required this.amened,
  });

  factory PostWitness.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    if (rawAuthor != null && rawAuthor is! Map) {
      throw const FormatException('Witness author is invalid.');
    }
    final author = rawAuthor == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawAuthor);
    final avatar = author['avatarUrl'];
    if (avatar != null && avatar is! String) {
      throw const FormatException('Witness author avatarUrl is invalid.');
    }
    final createdAt = DateTime.tryParse(_requiredString(json, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException('Witness createdAt date is invalid.');
    }
    return PostWitness(
      witnessId: _requiredString(json, 'witnessId'),
      postId: _requiredString(json, 'postId'),
      userId: _requiredString(json, 'userId'),
      content: _requiredString(json, 'content'),
      displayName: author['displayName'] is String
          ? author['displayName'] as String
          : 'Unknown user',
      avatarUrl: avatar as String?,
      createdAt: createdAt,
      amenCount: _requiredInt(json, 'amenCount'),
      amened: _requiredBool(json, 'amened'),
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
      throw const FormatException('Post author handle is invalid.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('Post author avatarUrl is invalid.');
    }
    if (tribeCode != null && tribeCode is! int) {
      throw const FormatException('Post author tribeCode is invalid.');
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
    throw FormatException('$field must be an object');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Post field $key is invalid.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Post field $key is invalid.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Post field $key is invalid.');
  }
  return value;
}
