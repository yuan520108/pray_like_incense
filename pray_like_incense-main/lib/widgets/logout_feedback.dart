import 'package:flutter/material.dart';

class LogoutFeedback extends StatelessWidget {
  final VoidCallback onLogout;
  final String message;

  const LogoutFeedback({
    super.key,
    required this.onLogout,
    this.message = '確定要登出嗎？',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登出確認'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            onLogout();
            Navigator.of(context).pop();
            // 显示登出成功消息
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已成功登出')),
            );
          },
          child: const Text('登出'),
        ),
      ],
    );
  }
}