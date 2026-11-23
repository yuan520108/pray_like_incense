import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'home/home_page.dart';
import 'pages/auth_page.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/media_service.dart';
import 'services/notifications_service.dart';
import 'services/posts_service.dart';
import 'services/witness_service.dart';
import 'services/ycoin_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  final authService = AuthService(apiClient);

  runApp(
    PrayLikeApp(
      apiClient: apiClient,
      authService: authService,
      postsRepository: PostsService(apiClient.dio),
      yCoinService: YCoinService(apiClient.dio),
      witnessService: WitnessService(apiClient.dio),
      mediaService: MediaService(apiClient.dio),
      notificationsService: NotificationsService(apiClient.dio),
    ),
  );
}

class PrayLikeApp extends StatelessWidget {
  final ApiClient apiClient;
  final AuthService authService;
  final PostsService postsRepository;
  final YCoinService yCoinService;
  final WitnessService witnessService;
  final MediaService mediaService;
  final NotificationsService notificationsService;

  const PrayLikeApp({
    super.key,
    required this.apiClient,
    required this.authService,
    required this.postsRepository,
    required this.yCoinService,
    required this.witnessService,
    required this.mediaService,
    required this.notificationsService,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    title: 'Pray like incense',
    theme: ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: appBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: appBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: ColorScheme.fromSeed(seedColor: appGold),
    ),
    home: _AuthenticationGate(
      apiClient: apiClient,
      authService: authService,
      postsRepository: postsRepository,
      yCoinService: yCoinService,
      witnessService: witnessService,
      mediaService: mediaService,
      notificationsService: notificationsService,
    ),
  );
}

class _AuthenticationGate extends StatefulWidget {
  final ApiClient apiClient;
  final AuthService authService;
  final PostsService postsRepository;
  final YCoinService yCoinService;
  final WitnessService witnessService;
  final MediaService mediaService;
  final NotificationsService notificationsService;

  const _AuthenticationGate({
    required this.apiClient,
    required this.authService,
    required this.postsRepository,
    required this.yCoinService,
    required this.witnessService,
    required this.mediaService,
    required this.notificationsService,
  });

  @override
  State<_AuthenticationGate> createState() => _AuthenticationGateState();
}

class _AuthenticationGateState extends State<_AuthenticationGate> {
  late Future<Map<String, dynamic>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = widget.authService.getMe();
  }

  Future<void> _reloadUser() async {
    final future = widget.authService.getMe();
    setState(() {
      _userFuture = future;
    });
    await future;
  }

  void _retryUserCheck() {
    final future = widget.authService.getMe();
    setState(() {
      _userFuture = future;
    });
  }

  Future<void> _logout() async {
    try {
      await widget.authService.logout();
    } finally {
      if (mounted) {
        final future = widget.authService.getMe();
        setState(() {
          _userFuture = future;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (snapshot.hasError) {
          final error = snapshot.error!;
          if (error is! UnauthenticatedException) {
            return Scaffold(
              backgroundColor: appBackground,
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: Colors.white70,
                          size: 44,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to check your sign-in status.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _retryUserCheck,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          return AuthPage(
            authService: widget.authService,
            onAuthenticated: _reloadUser,
          );
        }
        if (user == null) {
          return Scaffold(
            backgroundColor: appBackground,
            body: SafeArea(
              child: Center(
                child: ElevatedButton(
                  onPressed: _retryUserCheck,
                  child: const Text('Try again'),
                ),
              ),
            ),
          );
        }
        return HomePage(
          user: user,
          apiClient: widget.apiClient,
          authService: widget.authService,
          postsRepository: widget.postsRepository,
          yCoinService: widget.yCoinService,
          witnessService: widget.witnessService,
          mediaService: widget.mediaService,
          notificationsService: widget.notificationsService,
          onLogout: _logout,
        );
      },
    );
  }
}
