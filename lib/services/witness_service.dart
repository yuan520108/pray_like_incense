import 'package:dio/dio.dart';
import 'posts_service.dart' as posts;

class WitnessService {
  final Dio _dio;

  WitnessService(this._dio);

  Future<WitnessEntry> createWitness({
    required String postId,
    required String content,
    String? imageMediaId,
  }) async {
    final request = <String, dynamic>{'content': content};
    if (imageMediaId != null) {
      request['imageMediaId'] = imageMediaId;
    }

    try {
      final response = await _dio.post(
        'v1/posts/$postId/witnesses',
        data: request,
      );
      final body = _asMap(response.data, 'witness response');
      final data = _asMap(body['data'], 'witness response data');
      return WitnessEntry.fromJson(
        _asMap(data['item'], 'witness response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to publish witness', error);
    }
  }

  Future<WitnessFeedPage> getFeed({
    String? category,
    String? cursor,
    int pageSize = 25,
  }) async {
    final request = <String, dynamic>{'pageSize': pageSize};
    if (category != null && category.isNotEmpty) {
      request['category'] = category;
    }
    if (cursor != null && cursor.isNotEmpty) {
      request['cursor'] = cursor;
    }

    try {
      final response = await _dio.post(
        'v1/posts/witnesses/query',
        data: request,
      );
      return WitnessFeedPage.fromJson(
        _asMap(response.data, 'witness feed response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load witnesses', error);
    }
  }

  Future<WitnessFeedPage> getWitnessesForPost({required String postId}) async {
    try {
      final response = await _dio.post(
        'v1/posts/$postId/witnesses/query',
        data: <String, dynamic>{},
      );
      return WitnessFeedPage.fromJson(
        _asMap(response.data, 'post witness list response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load post witnesses', error);
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

class WitnessFeedPage {
  final List<WitnessEntry> items;
  final String? nextCursor;

  const WitnessFeedPage({required this.items, required this.nextCursor});

  factory WitnessFeedPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'witness list response data');
    final rawItems = data['items'];
    final rawCursor = data['nextCursor'];
    if (rawItems is! List) {
      throw const FormatException(
        'Witness list response data.items must be a list.',
      );
    }
    if (rawCursor != null && rawCursor is! String) {
      throw const FormatException(
        'Witness list response data.nextCursor has an invalid format.',
      );
    }

    return WitnessFeedPage(
      items: rawItems
          .map(
            (item) => WitnessEntry.fromJson(_asMap(item, 'witness list item')),
          )
          .toList(growable: false),
      nextCursor: rawCursor as String?,
    );
  }
}

class WitnessEntry {
  final String witnessId;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? imageUrl;
  final posts.PrayerPostAuthor? author;
  final posts.PrayerPost? originalPost;
  final int amenCount;
  final bool amened;

  const WitnessEntry({
    required this.witnessId,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.imageUrl,
    required this.author,
    required this.originalPost,
    required this.amenCount,
    required this.amened,
  });

  factory WitnessEntry.fromJson(Map<String, dynamic> json) {
    final rawAuthor = json['author'];
    final rawOriginalPost = json['originalPost'];
    if (rawAuthor != null && rawAuthor is! Map) {
      throw const FormatException('Witness author has an invalid format.');
    }
    if (rawOriginalPost != null && rawOriginalPost is! Map) {
      throw const FormatException(
        'Witness originalPost has an invalid format.',
      );
    }

    final imageUrl = json['imageUrl'];
    if (imageUrl != null && imageUrl is! String) {
      throw const FormatException('Witness imageUrl has an invalid format.');
    }

    return WitnessEntry(
      witnessId: _requiredString(json, 'witnessId'),
      postId: _requiredString(json, 'postId'),
      userId: _requiredString(json, 'userId'),
      content: _requiredString(json, 'content'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      imageUrl: imageUrl as String?,
      author: rawAuthor == null
          ? null
          : posts.PrayerPostAuthor.fromJson(
              Map<String, dynamic>.from(rawAuthor),
            ),
      originalPost: rawOriginalPost == null
          ? null
          : posts.PrayerPost.fromJson(
              Map<String, dynamic>.from(rawOriginalPost),
            ),
      amenCount: _requiredInt(json, 'amenCount'),
      amened: _requiredBool(json, 'amened'),
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

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_requiredString(json, key));
  if (value == null) {
    throw FormatException('Field $key date has an invalid format.');
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}
