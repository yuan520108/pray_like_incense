import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/services/api_client.dart';
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
        pageSize: 10,
      );

      expect(request!.method, 'POST');
      expect(request!.path, 'v1/posts/feed');
      expect(request!.data, {
        'scope': 'all',
        'mode': 'latest',
        'pageSize': 10,
        'category': 'Personal & Family',
        'cursor': 'current-page',
      });
      expect(page.items, hasLength(1));
      expect(page.items.single.author?.displayName, 'Prayer User');
      expect(page.nextCursor, 'next-page');
    },
  );

  test('comments use ten-item cursor pages', () async {
    RequestOptions? request;
    final service = PostsService(
      _dioReturning(
        (_) => {
          'status': 'success',
          'data': {'items': [], 'nextCursor': 'next-comments'},
        },
        (options) => request = options,
      ),
    );

    final page = await service.getComments('post-1', cursor: 'comment-cursor');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/post-1/comments/query');
    expect(request!.data, {'pageSize': 10, 'cursor': 'comment-cursor'});
    expect(page.items, isEmpty);
    expect(page.nextCursor, 'next-comments');
  });

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

  test('comment Amen uses the documented comment target type', () async {
    RequestOptions? request;
    final service = PostsService(
      _dioReturning(
        (_) => {
          'status': 'success',
          'data': {
            'item': {'amenCount': 3, 'amened': true},
          },
        },
        (options) => request = options,
      ),
    );

    final engagement = await service.amenComment('comment-1');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/amen');
    expect(request!.data, {'targetId': 'comment-1', 'targetType': 'comment'});
    expect(engagement.amenCount, 3);
    expect(engagement.amened, isTrue);
  });

  test('witness query loads testimonies without a request body', () async {
    RequestOptions? request;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://testpray.54ucl.com/api/',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Origin': 'https://testpray.54ucl.com',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'success',
                'data': {
                  'items': [
                    {
                      'witnessId': 'witness-1',
                      'postId': 'post-1',
                      'userId': 'user-1',
                      'content': 'I am trusting God.',
                      'createdAt': '2026-11-09T10:00:00+00:00',
                      'imageUrl': null,
                      'amenCount': 2,
                      'amened': true,
                      'author': {
                        'userId': 'user-1',
                        'displayName': 'Prayer User',
                        'handle': null,
                        'avatarUrl': null,
                        'tribeCode': null,
                      },
                      'originalPost': null,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );
    final service = PostsService(dio);

    final witnesses = await service.getWitnesses('post-1');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/post-1/witnesses/query');
    expect(request!.data, isNull);
    expect(request!.extra[ApiClient.omitContentTypeExtraKey], isTrue);
    expect(witnesses, hasLength(1));
    expect(witnesses.single.content, 'I am trusting God.');
    expect(witnesses.single.displayName, 'Prayer User');
    expect(witnesses.single.amenCount, 2);
    expect(witnesses.single.amened, isTrue);
  });

  test('duplicate testimony conflict has a clear message', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://testpray.54ucl.com/api/'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 409,
                data: {'code': 'WITNESS_ALREADY_EXISTS'},
              ),
            ),
          );
        },
      ),
    );
    final service = PostsService(dio);

    expect(
      () => service.createWitness('post-1', 'A testimony'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('already shared a testimony'),
        ),
      ),
    );
  });

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
