import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';

class NotificationPage extends StatefulWidget {
  final NotificationsService notificationsService;

  const NotificationPage({super.key, required this.notificationsService});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final List<NotificationItem> _items = [];
  final ScrollController _scrollController = ScrollController();
  String? _nextCursor;
  String? _errorMessage;
  int _unreadCount = 0;
  int _requestToken = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    if (!refresh && !_hasMore) return;
    if (refresh) {
      _requestToken++;
      _isLoading = false;
      _nextCursor = null;
      _hasMore = true;
      _items.clear();
    }

    final requestToken = ++_requestToken;
    final unreadOnly = _unreadOnly;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await widget.notificationsService.getFeed(
        cursor: _nextCursor,
        pageSize: 25,
        unreadOnly: unreadOnly,
      );
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _unreadCount = page.unreadCount;
        _hasMore = page.nextCursor != null && page.nextCursor!.isNotEmpty;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _requestToken) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _selectUnreadOnly(bool unreadOnly) async {
    if (_unreadOnly == unreadOnly) return;
    setState(() => _unreadOnly = unreadOnly);
    await _loadNotifications(refresh: true);
  }

  Future<void> _markRead(int index) async {
    final notification = _items[index];
    if (notification.isRead) return;
    try {
      await widget.notificationsService.markRead(notification.notificationId);
      if (!mounted) return;
      setState(() {
        if (_unreadOnly) {
          _items.removeAt(index);
        } else {
          _items[index] = notification.copyWith(isRead: true);
        }
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _requestToken++;
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('🔔 Notifications'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _notificationTab(
                  label: 'All',
                  selected: !_unreadOnly,
                  onTap: () => _selectUnreadOnly(false),
                ),
                const SizedBox(width: 10),
                _notificationTab(
                  label: 'Unread ($_unreadCount)',
                  selected: _unreadOnly,
                  onTap: () => _selectUnreadOnly(true),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadNotifications(refresh: true),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    if (_isLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_errorMessage != null) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: _loadNotifications,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (_items.isEmpty) return _buildEmptyState();
                    if (!_hasMore) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No more notifications',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return _buildNotification(_items[index], index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? appGold : Colors.transparent,
          border: Border.all(color: selected ? appGold : Colors.white24),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔔', style: TextStyle(fontSize: 74)),
          SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              "You'll see notifications here when someone interacts with your posts",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCDD4E5), fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotification(NotificationItem notification, int index) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: appCream,
        border: notification.isRead
            ? null
            : Border.all(color: appYellow, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: appGold,
          backgroundImage: notification.actor?.avatarUrl == null
              ? null
              : NetworkImage(_resolveMediaUrl(notification.actor!.avatarUrl!)),
          child: notification.actor?.avatarUrl == null
              ? const Icon(Icons.notifications, color: appIconBrown)
              : null,
        ),
        title: Text(
          _notificationText(notification),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.postTitle != null) Text(notification.postTitle!),
            if (notification.postPreview != null)
              Text(
                notification.postPreview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            Text(_formatDate(notification.createdAt)),
          ],
        ),
        trailing: notification.isRead
            ? null
            : const Icon(Icons.circle, size: 10, color: appYellow),
        onTap: () async {
          await _markRead(index);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_notificationText(notification)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.postTitle != null)
                    Text(
                      notification.postTitle!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (notification.postPreview != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(notification.postPreview!),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_formatDate(notification.createdAt)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _notificationText(NotificationItem notification) {
    final actorName =
        notification.actorName ?? notification.actor?.displayName ?? 'Someone';
    final action = switch (notification.messageKey) {
      'postCreated' => 'published a post',
      'witnessCreated' => 'added a testimony',
      'commentedOnPost' => 'prayed for your post',
      'amenedPost' => 'said Amen to your post',
      'amenedComment' => 'said Amen to a prayer',
      'amenedWitness' => 'said Amen to a testimony',
      'tribeActivityPublished' => 'published a tribe activity',
      'friendRequestReceived' => 'sent you a friend request',
      'friendRequestAccepted' => 'accepted your friend request',
      _ => 'sent you a notification',
    };
    return '$actorName $action';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _resolveMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(ApiClient.baseUrl).resolve(value).toString();
  }
}
