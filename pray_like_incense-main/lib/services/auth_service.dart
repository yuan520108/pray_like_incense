import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  // 1. 寄送 Email OTP
  Future<void> requestOtp(String email) async {
    try {
      await apiClient.dio.post('v1/auth/otp/request', data: {'email': email});
    } on DioException catch (e) {
      throw _apiError('Failed to send verification code', e);
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
        throw Exception('The verification response is invalid.');
      }

      final responseData = body['data'];
      final item = responseData is Map ? responseData['item'] : null;

      final result = item is Map ? item : body;

      return Map<String, dynamic>.from(result);
    } on DioException catch (e) {
      throw _apiError('Failed to verify code', e);
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

      final response = await apiClient.dio.post('v1/auth/register', data: data);

      final body = response.data;

      if (body is! Map) {
        throw Exception('The registration response is invalid.');
      }

      final responseData = body['data'];
      final item = responseData is Map ? responseData['item'] : null;

      final result = item is Map ? item : body;

      return Map<String, dynamic>.from(result);
    } on DioException catch (e) {
      throw _apiError('Registration failed', e);
    }
  }

  // 4. 查詢目前登入使用者
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await apiClient.dio.get('v1/auth/me');

      final body = response.data;

      if (body is! Map) {
        throw Exception('The sign-in response is invalid.');
      }

      final responseData = body['data'];
      final item = responseData is Map ? responseData['item'] : null;

      return Map<String, dynamic>.from(item is Map ? item : body);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) rethrow;
      throw _apiError('Failed to check sign-in status', e);
    }
  }

  // 5. 登出此裝置並清除本機保存的 Cookie
  Future<void> logout() async {
    try {
      await apiClient.logoutSession();
    } finally {
      await apiClient.cookieJar.deleteAll();
    }
  }

  // 6. Google OAuth 登入
  Future<String> startGoogleLogin() async {
    try {
      final response = await apiClient.dio.post(
        'v1/auth/oauth/google/start',
        data: {'client': 'app'},
      );

      final body = response.data;

      if (body is! Map) {
        throw Exception('The server response is invalid.');
      }

      final responseData = body['data'];
      final item = responseData is Map ? responseData['item'] : null;

      final authorizationUrl = item is Map ? item['authorizationUrl'] : null;

      if (authorizationUrl is! String || authorizationUrl.isEmpty) {
        throw Exception(
          'The server did not provide a Google authorization URL.',
        );
      }

      return authorizationUrl;
    } on DioException catch (e) {
      throw _apiError('Google sign-in failed', e);
    }
  }

  // 統一處理 API 錯誤
  Exception _apiError(String action, DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;

    if (body is Map) {
      final code = body['code'];

      if (code == 'OAUTH_PROVIDER_DISABLED') {
        return Exception('Google sign-in is not enabled in this environment.');
      }
    }

    if (statusCode != null) {
      return Exception('$action (HTTP $statusCode).');
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return Exception(
          'Connection timed out. Check your internet connection.',
        );

      case DioExceptionType.receiveTimeout:
        return Exception('The server response timed out.');

      case DioExceptionType.connectionError:
        return Exception('Unable to connect. Check your internet connection.');

      case DioExceptionType.badCertificate:
        return Exception(
          'The server security certificate could not be verified.',
        );

      default:
        return Exception('$action: ${e.message ?? e.type.name}');
    }
  }
}
