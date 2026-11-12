import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/services/api_client.dart';

void main() {
  test('API client omits content type when a request opts out', () async {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiClient.baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Origin': ApiClient.origin,
        },
      ),
    );
    final client = ApiClient.forTesting(
      dio: dio,
      refreshDio: Dio(BaseOptions(baseUrl: ApiClient.baseUrl)),
      cookieJar: CookieJar(),
    );
    RequestOptions? capturedRequest;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedRequest = options;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'status': 'success'},
            ),
          );
        },
      ),
    );

    await dio.post<void>(
      'v1/posts/post-1/witnesses/query',
      options: Options(extra: {ApiClient.omitContentTypeExtraKey: true}),
    );

    expect(capturedRequest!.data, isNull);
    expect(
      capturedRequest!.headers.containsKey(Headers.contentTypeHeader),
      isFalse,
    );
    await client.cookieJar.deleteAll();
  });

  test(
    'concurrent 401 responses share one refresh and retry requests',
    () async {
      final cookieJar = CookieJar();
      final origin = Uri.parse(ApiClient.baseUrl);
      await cookieJar.saveFromResponse(origin, [
        Cookie('identity_access', 'expired')..path = '/',
        Cookie('identity_refresh', 'refresh-1')..path = '/api/v1/auth',
      ]);

      var refreshCount = 0;
      _ResourceAdapter.totalRequests = 0;
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiClient.baseUrl,
          headers: {'Accept': 'application/json', 'Origin': ApiClient.origin},
        ),
      );
      dio.httpClientAdapter = _ResourceAdapter();
      refreshDio.httpClientAdapter = _RefreshAdapter(
        onRefresh: () => refreshCount++,
      );
      final client = ApiClient.forTesting(
        dio: dio,
        refreshDio: refreshDio,
        cookieJar: cookieJar,
      );

      final responses = await Future.wait(
        List.generate(
          4,
          (index) => dio.get<Map<String, dynamic>>('resource/$index'),
        ),
      );

      expect(responses, hasLength(4));
      expect(responses.every((response) => response.statusCode == 200), isTrue);
      expect(refreshCount, 1);
      expect(_ResourceAdapter.totalRequests, 8);
      final cookies = await cookieJar.loadForRequest(
        Uri.parse('${ApiClient.baseUrl}v1/auth/refresh'),
      );
      expect(
        cookies
            .singleWhere((cookie) => cookie.name == 'identity_refresh')
            .value,
        'refresh-2',
      );

      await client.cookieJar.deleteAll();
    },
  );
}

class _ResourceAdapter implements HttpClientAdapter {
  static int totalRequests = 0;
  final Map<String, int> _requestsByPath = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    totalRequests++;
    final requestCount = (_requestsByPath[options.path] ?? 0) + 1;
    _requestsByPath[options.path] = requestCount;
    if (requestCount == 1) {
      return ResponseBody.fromString(
        '{"status":"error","code":"AUTHENTICATION_REQUIRED"}',
        401,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RefreshAdapter implements HttpClientAdapter {
  final void Function() onRefresh;

  _RefreshAdapter({required this.onRefresh});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRefresh();
    expect(options.data, isNull);
    expect(options.headers.containsKey(Headers.contentTypeHeader), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return ResponseBody.fromString(
      '{"status":"success"}',
      200,
      headers: {
        'content-type': ['application/json'],
        'set-cookie': [
          'identity_access=fresh; Path=/',
          'identity_refresh=refresh-2; Path=/api/v1/auth',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
