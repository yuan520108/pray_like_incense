import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/social_service.dart';

class NotificationsPage extends StatefulWidget {
  final SocialRepository repository;

  const NotificationsPage({super.key, required this.repository});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _pageSize = 50;

  final List<NotificationPage> _pages = [];
  int _currentPage = 0;
  int _unreadCount = 0;
  bool _showUnreadOnly = false;
  bool _isLoading = true;
  bool _isLoadingNext = false;
  String? _error;

  NotificationPage? get _activePage =>
      _pages.isEmpty ? null : _pages[_currentPage];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _pages.clear();
      _currentPage = 0;
    });
    try {
      final result = await widget.repository.getNotifications(
        pageSize: _pageSize,
        unreadOnly: _showUnreadOnly,
      );
      final unreadCount =
          result.unreadCount ??
          await widget.repository.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() {
        _pages.add(result);
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _changeFilter(bool unreadOnly) async {
    if (_showUnreadOnly == unreadOnly) return;
    setState(() => _showUnreadOnly = unreadOnly);
    await _loadNotifications();
  }

  Future<void> _showNextPage() async {
    if (_isLoadingNext) return;
    if (_currentPage + 1 < _pages.length) {
      setState(() => _currentPage++);
      return;
    }
    final cursor = _activePage?.nextCursor;
    if (cursor == null || cursor.isEmpty) return;
    setState(() {
      _isLoadingNext = true;
      _error = null;
    });
    try {
      final page = await widget.repository.getNotifications(
        cursor: cursor,
        pageSize: _pageSize,
        unreadOnly: _showUnreadOnly,
      );
      if (!mounted) return;
      setState(() {
        _pages.add(page);
        _currentPage++;
        _unreadCount = page.unreadCount ?? _unreadCount;
        _isLoadingNext = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(error);
        _isLoadingNext = false;
      });
    }
  }

  void _showPreviousPage() {
    if (_currentPage == 0) return;
    setState(() => _currentPage--);
  }

  Future<void> _markRead(SocialNotification notification) async {
    try {
      await widget.repository.markNotificationRead(notification.notificationId);
      if (!mounted) return;
      setState(() {
        _replaceNotifications(
          (item) => item.notificationId == notification.notificationId
              ? _withReadState(item, true)
              : item,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.repository.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _replaceNotifications((item) => _withReadState(item, true));
        _unreadCount = 0;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  void _replaceNotifications(
    SocialNotification Function(SocialNotification) update,
  ) {
    for (var index = 0; index < _pages.length; index++) {
      final page = _pages[index];
      _pages[index] = NotificationPage(
        items: page.items
            .map(update)
            .where(
              (notification) =>
                  !_showUnreadOnly || !notification.isRead,
            )
            .toList(growable: false),
        nextCursor: page.nextCursor,
        unreadCount: page.unreadCount,
      );
    }
  }

  SocialNotification _withReadState(
    SocialNotification notification,
    bool isRead,
  ) => SocialNotification(
    notificationId: notification.notificationId,
    message: notification.message,
    notificationType: notification.notificationType,
    isRead: isRead,
    createdAt: notification.createdAt,
  );

  @override
  Widget build(BuildContext context) {
    final activePage = _activePage;
    final notifications = activePage?.items ?? const <SocialNotification>[];
    final hasPrevious = _currentPage > 0;
    final hasNext = activePage?.nextCursor?.isNotEmpty == true ||
        _currentPage + 1 < _pages.length;
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('notifications-header'),
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: OutlinedButton(
                          key: const ValueKey('notifications-back'),
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '🔔 Notifications',
                    key: ValueKey('notifications-title'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: appSurface),
            SizedBox(
              height: 58,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterButton(
                      label: 'All',
                      selected: !_showUnreadOnly,
                      onTap: () => _changeFilter(false),
                    ),
                    const SizedBox(width: 10),
                    _filterButton(
                      label: 'Unread ($_unreadCount)',
                      selected: _showUnreadOnly,
                      onTap: () => _changeFilter(true),
                    ),
                  ],
                ),
              ),
            ),
            if (_unreadCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('mark-all-notifications-read'),
                  onPressed: _markAllRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(color: appSelected),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: appSelected),
                    )
                  : _error != null
                  ? _emptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'Could not load notifications',
                      message: _error!,
                      action: TextButton(
                        onPressed: _loadNotifications,
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: appSelected),
                        ),
                      ),
                    )
                  : notifications.isEmpty
                  ? _emptyState(
                      icon: Icons.notifications,
                      title: 'No notifications yet',
                      message:
                          "You'll see notifications here when someone\n"
                          'interacts with your posts',
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            key: const ValueKey('notifications-list'),
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                            itemCount: notifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _notificationTile(notifications[index]),
                          ),
                        ),
                        if (hasPrevious || hasNext)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  key: const ValueKey(
                                    'notifications-previous-page',
                                  ),
                                  onPressed: hasPrevious
                                      ? _showPreviousPage
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'Page ${_currentPage + 1}',
                                    key: const ValueKey(
                                      'notifications-page-number',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  key: const ValueKey('notifications-next-page'),
                                  onPressed: hasNext && !_isLoadingNext
                                      ? _showNextPage
                                      : null,
                                  child: _isLoadingNext
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Next'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? appSelected : const Color(0xFF354160),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? appSelected : const Color(0xFF59647F),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 16,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'serif',
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 88, color: appSelected.withValues(alpha: 0.48)),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBEC2D0),
                  fontSize: 17,
                  height: 1.5,
                  fontFamily: 'serif',
                ),
              ),
              if (action != null) ...[const SizedBox(height: 8), action],
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationTile(SocialNotification notification) {
    return Material(
      key: ValueKey('notification-${notification.notificationId}'),
      color: notification.isRead ? appSurface : const Color(0xFF3B496D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: notification.isRead ? null : () => _markRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: appSelected,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        color: Color(0xFFBEC2D0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: CircleAvatar(radius: 4, backgroundColor: appSelected),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final time = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$date  $time';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
