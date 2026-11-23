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
    'editing sends title and content to the owner-only endpoint',
    () async {
      RequestOptions? request;
      final service = PostsService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {
              'item': _postJson(title: '', content: 'Updated prayer.'),
            },
          },
          (options) => request = options,
        ),
      );

      final updated = await service.updatePost(
        postId: 'post-1',
        title: null,
        content: 'Updated prayer.',
      );

      expect(request!.method, 'PUT');
      expect(request!.path, 'v1/posts/post-1');
      expect(request!.data, {
        'title': null,
        'content': 'Updated prayer.',
      });
      expect(updated.content, 'Updated prayer.');
    },
  );

  test('Amen toggles use the documented target type and parse server state', () async {
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

    final result = await service.toggleAmen(
      targetId: 'post-1',
      targetType: 'post',
    );

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/amen');
    expect(request!.data, {
      'targetId': 'post-1',
      'targetType': 'post',
    });
    expect(result.amenCount, 3);
    expect(result.amened, isTrue);
  });

  test('comments use the documented create and cursor-list endpoints', () async {
    final comment = {
      'commentId': 'comment-1',
      'postId': 'post-1',
      'userId': 'user-1',
      'content': 'Amen.',
      'createdAt': '2026-11-04T10:00:00+00:00',
      'author': {
        'userId': 'user-1',
        'displayName': 'Prayer User',
        'handle': 'prayer-user',
        'avatarUrl': null,
        'tribeCode': null,
      },
      'amenCount': 0,
      'amened': false,
    };
    final requests = <RequestOptions>[];
    final service = PostsService(
      _dioReturning(
        (request) => request.path.endsWith('/comments')
            ? {
                'status': 'success',
                'data': {'item': comment},
              }
            : {
                'status': 'success',
                'data': {
                  'items': [comment],
                  'nextCursor': null,
                },
              },
        requests.add,
      ),
    );

    final created = await service.createComment(
      postId: 'post-1',
      content: 'Amen.',
    );
    final page = await service.getComments(
      postId: 'post-1',
      cursor: 'next-page',
      pageSize: 25,
    );

    expect(requests[0].method, 'POST');
    expect(requests[0].path, 'v1/posts/post-1/comments');
    expect(requests[0].data, {'content': 'Amen.'});
    expect(created.commentId, 'comment-1');
    expect(requests[1].path, 'v1/posts/post-1/comments/query');
    expect(requests[1].data, {'pageSize': 25, 'cursor': 'next-page'});
    expect(page.items.single.content, 'Amen.');
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
