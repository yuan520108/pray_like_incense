import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/posts_service.dart';
import 'services/ycoin_service.dart';
import 'services/witness_service.dart';
import 'home/home_page.dart';

late final AuthService authService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  authService = AuthService(apiClient);
  
  // Initialize services - need to pass dio instead of apiClient
  final yCoinService = YCoinService(apiClient.dio);
  final witnessService = WitnessService(apiClient.dio);
  
  runApp(PrayLikeApp(
    apiClient: apiClient,
    yCoinService: yCoinService,
    witnessService: witnessService,
  ));
}

class PrayLikeApp extends StatelessWidget {
  final ApiClient apiClient;
  final YCoinService yCoinService;
  final WitnessService witnessService;

  const PrayLikeApp({
    super.key,
    required this.apiClient,
    required this.yCoinService,
    required this.witnessService,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pray like incense',
    theme: ThemeData(useMaterial3: false, fontFamily: 'Arial'),
    home: HomePage(
      user: const {'userId': '1', 'username': 'Test User'},
      apiClient: apiClient,
      authService: authService,
      yCoinService: yCoinService,
      witnessService: witnessService,
      postsRepository: PostsService(apiClient.dio),
    ),
  );
}