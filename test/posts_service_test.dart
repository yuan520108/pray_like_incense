import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/services/posts_service.dart';

Map<String, dynamic> _postJson({
  String postId = 'post-1',
  String title = 'Prayer title',
  String content = 'Please pray for us.',
}) {
  return {
    'postId': postId,
    'userId': 'user-1',
    'author': {
      'userId': 'user-1',
      'displayName': 'Prayer User',
      'handle': 'prayer-user',
      'avatarUrl': null,
      'tribeCode': null,
    },
    'title': title,
    'content': content,
    'category': 'Personal & Family',
    'privacy': 'public',
    'createdAt': '2026-11-04T10:00:00+00:00',
    'amenCount': 2,
    'commentCount': 1,
    'amened': true,
    'witnessed': false,
  };
}

Dio _dioReturning(
  Map<String, dynamic> Function(RequestOptions request) responseFor,
  void Function(RequestOptions request)? onRequest,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://testpray.54ucl.com/api/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: options.path.endsWith('/posts') ? 201 : 200,
            data: responseFor(options),
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'feed sends documented all-scope cursor request and parses posts',
    () async {
      RequestOptions? request;
      final service = PostsService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {
              'items': [_postJson()],
              'nextCursor': 'next-page',
            },
          },
          (options) => request = options,
        ),
      );

      final page = await service.getFeed(
        category: 'Personal & Family',
        cursor: 'current-page',
        pageSize: 20,
      );

      expect(request!.method, 'POST');
      expect(request!.path, 'v1/posts/feed');
      expect(request!.data, {
        'scope': 'all',
        'mode': 'latest',
        'pageSize': 20,
        'category': 'Personal & Family',
        'cursor': 'current-page',
      });
      expect(page.items, hasLength(1));
      expect(page.items.single.author?.displayName, 'Prayer User');
      expect(page.nextCursor, 'next-page');
    },
  );

  test(
    'publishing sends documented fields and parses the created post',
    () async {
      RequestOptions? request;
      final service = PostsService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {'item': _postJson()},
          },
          (options) => request = options,
        ),
      );

      final post = await service.createPost(
        content: 'Please pray for us.',
        title: 'Prayer title',
        category: 'Personal & Family',
        privacy: 'public',
      );

      expect(request!.method, 'POST');
      expect(request!.path, 'v1/posts');
      expect(request!.data, {
        'content': 'Please pray for us.',
        'category': 'Personal & Family',
        'privacy': 'public',
        'title': 'Prayer title',
      });
      expect(post.postId, 'post-1');
      expect(post.content, 'Please pray for us.');
    },
  );

  test(
    'malformed feed response is reported instead of treated as empty',
    () async {
      final service = PostsService(
        _dioReturning((_) => {'status': 'success', 'data': {}}, null),
      );

      expect(
        () => service.getFeed(category: 'Personal & Family'),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
