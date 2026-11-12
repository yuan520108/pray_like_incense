import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'auth/login_page.dart';
import 'core/app_services.dart';
import 'home/home_page.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  authService = AuthService(apiClient);
  runApp(const PrayLikeApp());
}

class PrayLikeApp extends StatelessWidget {
  const PrayLikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pray like incense',
    theme: ThemeData(useMaterial3: false, fontFamily: 'Arial'),
    home: const AuthGate(),
  );
}

// ==================== 啟動時檢查登入狀態 ====================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Map<String, dynamic>?> _loginCheck;

  @override
  void initState() {
    super.initState();
    _loginCheck = _checkLogin();
  }

  Future<Map<String, dynamic>?> _checkLogin() async {
    try {
      return await authService.getMe();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  void _retryLoginCheck() {
    setState(() => _loginCheck = _checkLogin());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _loginCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to verify your sign-in status. Check your connection and try again.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retryLoginCheck,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;

        if (data is Map) {
          return HomePage(user: Map<String, dynamic>.from(data));
        }

        return const LoginPage();
      },
    );
  }
}

// ==================== 共用資料處理 ====================
