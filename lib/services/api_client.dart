import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  static const String baseUrl = 'https://testpray.54ucl.com/api/';
  static const String origin = 'https://testpray.54ucl.com';

  final Dio dio;
  final Dio _authDio;
  final CookieJar cookieJar;
  Future<void>? _refreshInProgress;

  ApiClient._({
    required this.dio,
    required this._authDio,
    required this.cookieJar,
  }) {
    dio.interceptors.add(CookieManager(cookieJar));
    _authDio.interceptors.add(CookieManager(cookieJar));
    dio.interceptors.add(_SessionRefreshInterceptor(this));
  }

  factory ApiClient.forTesting({
    required Dio dio,
    required Dio authDio,
    required CookieJar cookieJar,
  }) => ApiClient._(dio: dio, authDio: authDio, cookieJar: cookieJar);

  static Future<ApiClient> create() async {
    final appDirectory = await getApplicationSupportDirectory();
    final cookieJar = PersistCookieJar(
      storage: FileStorage('${appDirectory.path}/api_cookies/'),
    );

    return ApiClient._(
      cookieJar: cookieJar,
      dio: Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Origin': origin,
          },
        ),
      ),
      authDio: Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json', 'Origin': origin},
        ),
      ),
    );
  }

  Future<void> refreshSession() async {
    final inProgress = _refreshInProgress;
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final refresh = _performRefresh();
    _refreshInProgress = refresh;
    await refresh;
  }

  Future<void> _performRefresh() async {
    try {
      await _authDio.post<void>('v1/auth/refresh', data: null);
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<void> logoutSession() async {
    try {
      await _sendLogoutRequest();
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      await refreshSession();
      await _sendLogoutRequest();
    }
  }

  Future<void> _sendLogoutRequest() async {
    await _authDio.post<void>('v1/auth/logout', data: null);
  }
}

class _SessionRefreshInterceptor extends Interceptor {
  final ApiClient _client;

  _SessionRefreshInterceptor(this._client);

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        request.extra['retriedAfterRefresh'] == true ||
        _isExcludedFromRefresh(request.uri.path)) {
      handler.next(error);
      return;
    }

    try {
      await _client.refreshSession();
      request.extra['retriedAfterRefresh'] = true;
      handler.resolve(await _client.dio.fetch<dynamic>(request));
    } catch (refreshError) {
      if (refreshError is DioException &&
          refreshError.response?.statusCode == 401) {
        await _client.cookieJar.deleteAll();
        handler.next(error);
      } else {
        handler.next(
          refreshError is DioException
              ? refreshError
              : DioException(requestOptions: request, error: refreshError),
        );
      }
    }
  }

  bool _isExcludedFromRefresh(String path) {
    const excludedPaths = [
      '/v1/auth/otp/request',
      '/v1/auth/otp/verify',
      '/v1/auth/register',
      '/v1/auth/refresh',
      '/v1/auth/logout',
      '/v1/auth/logout-all',
      '/v1/auth/oauth/google/start',
    ];
    return excludedPaths.any(path.endsWith);
  }
}
