import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pray_like_incense/services/media_service.dart';
import 'package:pray_like_incense/services/witness_service.dart';

Dio _recordingDio(
  Map<String, dynamic> Function(RequestOptions request) responseFor,
  void Function(RequestOptions request) onRequest,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://testpray.54ucl.com/api/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 201,
            data: responseFor(options),
          ),
        );
      },
    ),
  );
  return dio;
}

Map<String, dynamic> _witnessJson({Map<String, dynamic>? originalPost}) {
  return {
    'witnessId': 'witness-1',
    'postId': 'post-1',
    'userId': 'user-1',
    'content': 'A witness story.',
    'createdAt': '2026-11-04T10:00:00+00:00',
    'imageUrl': '/api/v1/media/image-1/content',
    'author': {
      'userId': 'user-1',
      'displayName': 'Prayer User',
      'handle': null,
      'avatarUrl': null,
      'tribeCode': null,
    },
    'originalPost': originalPost,
    'amenCount': 1,
    'amened': false,
  };
}

void main() {
  test('image upload sends JSON base64 and parses the media id', () async {
    RequestOptions? request;
    final service = MediaService(
      _recordingDio(
        (_) => {
          'status': 'success',
          'data': {
            'item': {
              'mediaId': 'media-1',
              'url': '/api/v1/media/media-1/content',
              'thumbnailUrl': null,
              'byteSize': 3,
              'width': 1,
              'height': 1,
            },
          },
        },
        (options) => request = options,
      ),
    );

    final uploaded = await service.uploadImage(
      XFile.fromData(Uint8List.fromList([0, 1, 2]), name: 'witness.png'),
      purpose: 'witness',
    );

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/media/images');
    expect(request!.data, {
      'contentBase64': 'AAEC',
      'fileName': 'witness.jpg',
      'purpose': 'witness',
    });
    expect(uploaded.mediaId, 'media-1');
  });

  test('witness create uses the post-scoped route and imageMediaId', () async {
    RequestOptions? request;
    final service = WitnessService(
      _recordingDio(
        (_) => {
          'status': 'success',
          'data': {'item': _witnessJson()},
        },
        (options) => request = options,
      ),
    );

    final witness = await service.createWitness(
      postId: 'post-1',
      content: 'A witness story.',
      imageMediaId: 'media-1',
    );

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/post-1/witnesses');
    expect(request!.data, {
      'content': 'A witness story.',
      'imageMediaId': 'media-1',
    });
    expect(witness.witnessId, 'witness-1');
  });

  test('witness feed sends cursor request and parses original post', () async {
    RequestOptions? request;
    final originalPost = {
      'postId': 'post-1',
      'userId': 'owner-1',
      'author': {
        'userId': 'owner-1',
        'displayName': 'Post Owner',
        'handle': null,
        'avatarUrl': null,
        'tribeCode': null,
      },
      'title': 'Prayer',
      'content': 'Please pray.',
      'category': 'Personal & Family',
      'privacy': 'public',
      'createdAt': '2026-11-04T09:00:00+00:00',
      'amenCount': 1,
      'commentCount': 0,
      'amened': false,
      'witnessed': true,
    };
    final service = WitnessService(
      _recordingDio(
        (_) => {
          'status': 'success',
          'data': {
            'items': [_witnessJson(originalPost: originalPost)],
            'nextCursor': null,
          },
        },
        (options) => request = options,
      ),
    );

    final page = await service.getFeed(
      category: 'Personal & Family',
      cursor: 'next-page',
      pageSize: 25,
    );

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/posts/witnesses/query');
    expect(request!.data, {
      'pageSize': 25,
      'category': 'Personal & Family',
      'cursor': 'next-page',
    });
    expect(page.items.single.originalPost?.title, 'Prayer');
  });
}
