import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  final int notificationCount;
  final Function()? onNotificationTap;

  const NotificationPage({
    super.key,
    required this.notificationCount,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: notificationCount,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.notifications),
            title: Text('Notification $index'),
            subtitle: const Text('This is a sample notification'),
            onTap: onNotificationTap,
          );
        },
      ),
    );
  }
}