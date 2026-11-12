import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class ProfilePage extends StatelessWidget {
  final String name;
  final String handle;
  final String email;
  final String tribe;
  final String? avatarUrl;

  const ProfilePage({
    super.key,
    required this.name,
    required this.handle,
    required this.email,
    required this.tribe,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Profile',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ],
              ),
              const Divider(height: 32, color: Color(0xFF485473)),
              const SizedBox(height: 38),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9BC7FA),
                      shape: BoxShape.circle,
                      border: Border.all(color: cream, width: 2),
                    ),
                    child: ClipOval(
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF347BE5),
                              size: 112,
                            )
                          : Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                color: Color(0xFF347BE5),
                                size: 112,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00A451),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined, color: Colors.lightBlueAccent),
                    SizedBox(width: 10),
                    Text(
                      'Email',
                      style: TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 68),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
                decoration: BoxDecoration(
                  color: appSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _profileValue('Email', email),
                    _profileValue('Nickname', name),
                    _profileValue('User ID', handle),
                    _profileValue('Tribe', tribe, showDivider: false),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
                decoration: BoxDecoration(
                  color: appSurface,
                  border: Border.all(color: const Color(0xFF485473)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TERMS & CONDITIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 35),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(color: Colors.white, fontSize: 17),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFADB5C6),
                            side: const BorderSide(color: Color(0xFF596581)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Read in detail →'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileValue(String label, String value, {bool showDivider = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD0D2DC), fontSize: 17),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 21),
          ),
          if (showDivider) ...[
            const SizedBox(height: 26),
            const Divider(height: 1, color: Color(0xFF56617E)),
          ],
        ],
      ),
    );
  }
}

// ==================== 功能佔位頁面 ====================
