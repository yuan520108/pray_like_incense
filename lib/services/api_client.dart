import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'browser_credentials_stub.dart'
    if (dart.library.js_interop) 'browser_credentials_web.dart';

class ApiClient {
  static const String baseUrl = 'https://testpray.54ucl.com/api/';

  late final Dio dio;
  late final CookieJar cookieJar;

  ApiClient._();

  static Future<ApiClient> create() async {
    final client = ApiClient._();

    if (kIsWeb) {
      client.cookieJar = CookieJar();
    } else {
      final appDirectory = await getApplicationSupportDirectory();
      client.cookieJar = PersistCookieJar(
        storage: FileStorage('${appDirectory.path}/api_cookies/'),
      );
    }

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

    if (kIsWeb) {
      configureBrowserCredentials(client.dio);
    } else {
      client.dio.interceptors.add(CookieManager(client.cookieJar));
    }

    // 添加通用的拦截器来处理CSRF相关的请求头
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 为所有POST/PUT/DELETE请求添加常见的CSRF相关头
          if (options.method == 'POST' ||
              options.method == 'PUT' ||
              options.method == 'DELETE') {
            options.headers['X-Requested-With'] = 'XMLHttpRequest';
            options.headers['Referer'] = 'https://testpray.54ucl.com/';
            options.headers['Origin'] = 'https://testpray.54ucl.com';
          }
          return handler.next(options);
        },
      ),
    );

    return client;
  }
}
