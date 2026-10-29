
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  static const String baseUrl =
      'https://testpray.54ucl.com/api/';

  late final Dio dio;
  late final PersistCookieJar cookieJar;

  ApiClient._();

  static Future<ApiClient> create() async {
    final client = ApiClient._();

    final appDirectory = await getApplicationSupportDirectory();

    client.cookieJar = PersistCookieJar(
      storage: FileStorage(
        '${appDirectory.path}/api_cookies/',
      ),
    );

    client.dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Origin': 'https://testpray.54ucl.com',
        },
      ),
    );

    client.dio.interceptors.add(
      CookieManager(client.cookieJar),
    );

    // 顯示實際請求網址與錯誤，方便除錯
    client.dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );

    return client;
  }
}
