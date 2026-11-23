import 'package:flutter/material.dart';

class LogoutFeedback extends StatelessWidget {
  final VoidCallback onLogout;
  final String message;

  const LogoutFeedback({
    super.key,
    required this.onLogout,
    this.message = 'Are you sure you want to sign out?',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm sign out'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            onLogout();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signed out successfully.')),
            );
          },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
