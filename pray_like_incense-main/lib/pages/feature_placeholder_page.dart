import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: navy),
      body: Container(
        width: double.infinity,
        decoration: prayerGradient(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 80, color: cream),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This feature is coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: creamButton(),
                  child: const Text('BACK TO HOME'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
