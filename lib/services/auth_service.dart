import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  // 1. 寄送 Email OTP
  Future<void> requestOtp(String email) async {
    try {
      await apiClient.dio.post(
        'v1/auth/otp/request',
        data: {
          'email': email,
        },
      );
    } on DioException catch (e) {
      throw _apiError('寄送驗證碼失敗', e);
    }
  }

  // 2. 驗證 OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String code,
    String? registrationToken,
  }) async {
    try {
      final data = <String, dynamic>{
        'client': 'app',
        'email': email,
        'code': code,
      };

      if (registrationToken != null) {
        data['registrationToken'] = registrationToken;
      }

      final response = await apiClient.dio.post(
        'v1/auth/otp/verify',
        data: data,
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('驗證 API 回傳格式不正確');
      }

      final responseData = body['data'];
      final item =
          responseData is Map ? responseData['item'] : null;

      final result = item is Map ? item : body;

      return Map<String, dynamic>.from(result);
    } on DioException catch (e) {
      throw _apiError('驗證碼確認失敗', e);
    }
  }

  // 3. 新使用者註冊
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String handle,
    required String registrationToken,
    required bool termsAgreed,
    String? tribeCode,
  }) async {
    try {
      final data = <String, dynamic>{
        'displayName': displayName,
        'handle': handle,
        'registrationToken': registrationToken,
        'termsAgreed': termsAgreed,
      };

      if (tribeCode != null && tribeCode.isNotEmpty) {
        data['tribeCode'] = tribeCode;
      }

      final response = await apiClient.dio.post(
        'v1/auth/register',
        data: data,
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('註冊 API 回傳格式不正確');
      }

      final responseData = body['data'];
      final item =
          responseData is Map ? responseData['item'] : null;

      final result = item is Map ? item : body;

      return Map<String, dynamic>.from(result);
    } on DioException catch (e) {
      throw _apiError('註冊失敗', e);
    }
  }

  // 4. 查詢目前登入使用者
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await apiClient.dio.get(
        'v1/auth/me',
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('登入狀態回傳格式不正確');
      }

      final responseData = body['data'];
      final item =
          responseData is Map ? responseData['item'] : null;

      return Map<String, dynamic>.from(
        item is Map ? item : body,
      );
    } on DioException catch (e) {
      throw _apiError('查詢登入狀態失敗', e);
    }
  }

  // 5. 登出：清除本機保存的 Cookie
  Future<void> logout() async {
    await apiClient.cookieJar.deleteAll();
  }

  // 6. Google OAuth 登入
  Future<String> startGoogleLogin() async {
    try {
      final response = await apiClient.dio.post(
        'v1/auth/oauth/google/start',
        data: {
          'client': 'app',
        },
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('伺服器回傳格式不正確');
      }

      final responseData = body['data'];
      final item =
          responseData is Map ? responseData['item'] : null;

      final authorizationUrl =
          item is Map ? item['authorizationUrl'] : null;

      if (authorizationUrl is! String ||
          authorizationUrl.isEmpty) {
        throw Exception('伺服器沒有提供 Google 授權網址');
      }

      return authorizationUrl;
    } on DioException catch (e) {
      throw _apiError('Google 登入失敗', e);
    }
  }

  // 統一處理 API 錯誤
  Exception _apiError(String action, DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;

    debugPrint('$action：${e.requestOptions.uri}');
    debugPrint('HTTP 狀態碼：$statusCode');
    debugPrint('伺服器回應：$body');

    if (body is Map) {
      final code = body['code'];
      final message = body['message'];

      if (code == 'OAUTH_PROVIDER_DISABLED') {
        return Exception(
          '測試環境尚未啟用 Google 登入，請聯絡後端管理員',
        );
      }

      if (message != null) {
        return Exception('$action：$message');
      }
    }

    if (statusCode != null) {
      return Exception('$action（HTTP $statusCode）');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception('連線逾時，請檢查伺服器是否可連線');

      case DioExceptionType.receiveTimeout:
        return Exception('伺服器回應逾時');

      case DioExceptionType.connectionError:
        return Exception('無法建立網路連線，請檢查網路及伺服器');

      case DioExceptionType.badCertificate:
        return Exception('伺服器 HTTPS 憑證驗證失敗');

      default:
        return Exception(
          '$action：${e.message ?? e.type.name}',
        );
    }
  }
}