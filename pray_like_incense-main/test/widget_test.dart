import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/home/home_page.dart';
import 'package:pray_like_incense/services/posts_service.dart';
import 'package:pray_like_incense/services/social_service.dart';
import 'package:pray_like_incense/services/ycoin_service.dart';

class _FakeYcoinRepository implements YcoinRepository {
  @override
  Future<String> getBalance() async => '12.75';

  @override
  Future<YcoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    return YcoinTransactionPage(
      items: [
        YcoinTransaction(
          amountCents: 100,
          description: 'reward.post',
          eventType: 'post',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        YcoinTransaction(
          amountCents: 20,
          description: 'reward.amen',
          eventType: 'amen',
          createdAt: DateTime.utc(2026, 10, 22),
        ),
        YcoinTransaction(
          amountCents: 100,
          description: 'reward.comment',
          eventType: 'comment',
          createdAt: DateTime.utc(2026, 10, 21),
        ),
      ],
      page: page,
      hasNext: false,
    );
  }
}

class _UnavailableBalanceRepository implements YcoinRepository {
  @override
  Future<String> getBalance() async {
    throw Exception('Balance service unavailable');
  }

  @override
  Future<YcoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    return YcoinTransactionPage(items: const [], page: page, hasNext: false);
  }
}

class _RefreshingBalanceRepository implements YcoinRepository {
  final Completer<String> refresh = Completer<String>();
  int calls = 0;

  @override
  Future<String> getBalance() {
    calls++;
    return calls == 1 ? Future.value('12.75') : refresh.future;
  }

  @override
  Future<YcoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    return YcoinTransactionPage(items: const [], page: page, hasNext: false);
  }
}

class _FakeSocialRepository implements SocialRepository {
  String activeAccount = 'account-a';
  int unreadCount = 0;
  final List<SocialNotification> notifications = [];
  final List<(String?, int, bool)> notificationQueries = [];
  final List<String> invitationsSent = [];
  final List<(String, bool)> invitationResponses = [];
  final Map<String, List<FriendInvitation>> incomingByAccount = {};
  final Map<String, List<SocialUser>> friendsByAccount = {};

  @override
  Future<List<SocialUser>> getFriends() async =>
      List.of(friendsByAccount[activeAccount] ?? const []);

  @override
  Future<List<FriendInvitation>> getIncomingInvitations() async =>
      List.of(incomingByAccount[activeAccount] ?? const []);

  @override
  Future<NotificationPage> getNotifications({
    String? cursor,
    int pageSize = 50,
    bool unreadOnly = false,
  }) async {
    notificationQueries.add((cursor, pageSize, unreadOnly));
    final filtered = unreadOnly
        ? notifications.where((notification) => !notification.isRead).toList()
        : notifications;
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final end = (offset + pageSize).clamp(0, filtered.length).toInt();
    final pageItems = filtered.skip(offset).take(end - offset).toList();
    final nextCursor = end < filtered.length ? '$end' : null;
    return NotificationPage(
      items: pageItems,
      nextCursor: nextCursor,
      unreadCount: unreadCount,
    );
  }

  @override
  Future<int> getUnreadNotificationCount() async => unreadCount;

  @override
  Future<void> markAllNotificationsRead() async {
    unreadCount = 0;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    unreadCount--;
    final index = notifications.indexWhere(
      (notification) => notification.notificationId == notificationId,
    );
    if (index >= 0) {
      final notification = notifications[index];
      notifications[index] = SocialNotification(
        notificationId: notification.notificationId,
        message: notification.message,
        notificationType: notification.notificationType,
        isRead: true,
        createdAt: notification.createdAt,
      );
    }
  }

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    invitationResponses.add((invitationId, accept));
    final incoming = incomingByAccount[activeAccount] ?? [];
    final index = incoming.indexWhere(
      (invitation) => invitation.invitationId == invitationId,
    );
    if (index < 0) return;
    final invitation = incoming.removeAt(index);
    if (accept) {
      final currentUser = SocialUser(
        userId: invitation.userId,
        displayName: 'Account A',
        handle: 'account-a',
        avatarUrl: null,
        relation: 'friend',
      );
      final acceptedUser = SocialUser(
        userId: activeAccount,
        displayName: 'Account B',
        handle: 'account-b',
        avatarUrl: null,
        relation: 'friend',
      );
      (friendsByAccount[activeAccount] ??= []).add(currentUser);
      (friendsByAccount[invitation.userId] ??= []).add(acceptedUser);
    }
  }

  @override
  Future<List<SocialUser>> searchUsers(String query) async => [
    const SocialUser(
      userId: 'account-b',
      displayName: 'Account B',
      handle: 'account-b',
      avatarUrl: null,
      relation: 'none',
    ),
  ];

  @override
  Future<void> sendFriendInvitation(String targetUserId) async {
    invitationsSent.add(targetUserId);
    (incomingByAccount[targetUserId] ??= []).add(
      FriendInvitation(
        invitationId: 'invitation-a-b',
        userId: activeAccount,
        displayName: 'Account A',
        avatarUrl: null,
        incoming: true,
      ),
    );
  }
}

class _FakePostsRepository implements PostsRepository {
  final List<PrayerPost> posts = [];
  String? publishedContent;
  String? publishedTitle;
  String? publishedCategory;
  String? publishedPrivacy;
  int amenCalls = 0;
  int commentAmenCalls = 0;
  final List<PostComment> comments = [];
  final List<PostWitness> witnesses = [];
  String? commentedPostId;
  String? commentContent;
  String? witnessedPostId;
  String? witnessContent;
  final List<String?> commentCursors = [];
  final List<int> feedPageSizes = [];

  @override
  Future<PostFeedPage> getFeed({
    required String category,
    String? cursor,
    int pageSize = 20,
  }) async {
    feedPageSizes.add(pageSize);
    return PostFeedPage(items: List.of(posts), nextCursor: null);
  }

  @override
  Future<PrayerPost> createPost({
    required String content,
    String? title,
    required String category,
    required String privacy,
  }) async {
    publishedContent = content;
    publishedTitle = title;
    publishedCategory = category;
    publishedPrivacy = privacy;
    final post = _post(
      postId: 'new-post',
      title: title,
      content: content,
      category: category,
      privacy: privacy,
    );
    posts.insert(0, post);
    return post;
  }

  @override
  Future<PostEngagement> amenPost(String postId) async {
    amenCalls++;
    return const PostEngagement(amenCount: 1, amened: true);
  }

  @override
  Future<PostEngagement> amenComment(String commentId) async {
    commentAmenCalls++;
    return const PostEngagement(amenCount: 1, amened: true);
  }

  @override
  Future<PostCommentPage> getComments(String postId, {String? cursor}) async {
    commentCursors.add(cursor);
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final end = (offset + 10).clamp(0, comments.length).toInt();
    return PostCommentPage(
      items: comments.skip(offset).take(end - offset).toList(),
      nextCursor: end < comments.length ? '$end' : null,
    );
  }

  @override
  Future<List<PostWitness>> getWitnesses(String postId) async =>
      List.of(witnesses);

  @override
  Future<void> createComment(String postId, String content) async {
    commentedPostId = postId;
    commentContent = content;
  }

  @override
  Future<void> createWitness(String postId, String content) async {
    witnessedPostId = postId;
    witnessContent = content;
  }
}

PrayerPost _post({
  required String postId,
  String? title,
  required String content,
  required String category,
  required String privacy,
  bool witnessed = false,
}) {
  return PrayerPost(
    postId: postId,
    userId: 'user-id',
    author: const PrayerPostAuthor(
      userId: 'user-id',
      displayName: 'Test User',
      handle: 'test-user',
      avatarUrl: null,
      tribeCode: null,
    ),
    title: title,
    content: content,
    category: category,
    privacy: privacy,
    createdAt: DateTime.utc(2026, 11, 4),
    amenCount: 0,
    commentCount: 0,
    amened: false,
    witnessed: witnessed,
  );
}

void main() {
  testWidgets('bottom navigation stays fixed when the keyboard opens', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {
            'displayName': 'Prayer User',
            'email': 'user@example.com',
          },
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-avatar')), findsOneWidget);
    expect(find.text('12.75'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-bottom-navigation')),
      findsOneWidget,
    );
    final firstNavIcon = tester.widget<Image>(
      find.byKey(const ValueKey('bottom-nav-icon-0')),
    );
    expect(
      (firstNavIcon.image as AssetImage).assetName,
      'assets/icons/Homeicon.png',
    );
    final secondNavIcon = tester.widget<Image>(
      find.byKey(const ValueKey('bottom-nav-icon-1')),
    );
    expect(
      (secondNavIcon.image as AssetImage).assetName,
      'assets/icons/pray.png',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav-circle-0'))),
      const Size(78, 78),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav-icon-box-0'))),
      const Size(54, 54),
    );
    for (var index = 1; index < 5; index++) {
      expect(
        tester.getSize(find.byKey(ValueKey('bottom-nav-circle-$index'))),
        const Size(64, 64),
      );
      expect(
        tester.getSize(find.byKey(ValueKey('bottom-nav-icon-box-$index'))),
        const Size(42, 42),
      );
    }
    expect(find.text('Activity'), findsNothing);
    final novaIcon = tester.widget<Image>(
      find.byKey(const ValueKey('bottom-nav-icon-4')),
    );
    expect((novaIcon.image as AssetImage).assetName, 'assets/icons/Nova.png');

    final bottomNavigation = find.byKey(
      const ValueKey('home-bottom-navigation'),
    );
    final initialPosition = tester.getTopLeft(bottomNavigation);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-4')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav-circle-4'))),
      const Size(78, 78),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav-icon-box-4'))),
      const Size(54, 54),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('bottom-nav-circle-0'))),
      const Size(64, 64),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getTopLeft(bottomNavigation).dy, initialPosition.dy);
  });

  testWidgets('comments load the next ten-item cursor page on scroll', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'post-comments',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
        ),
      )
      ..comments.addAll(
        List.generate(
          11,
          (index) => PostComment(
            commentId: 'comment-${index + 1}',
            content: 'Prayer comment ${index + 1}',
            userId: 'user-id',
            displayName: 'Prayer Friend',
            avatarUrl: null,
            createdAt: DateTime.utc(2026, 11, 9),
            amenCount: 0,
            amened: false,
          ),
        ),
      );
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('comment-post-post-comments')));
    await tester.pumpAndSettle();

    expect(find.text('Prayer comment 1'), findsOneWidget);
    expect(find.text('Prayer comment 11'), findsNothing);
    final commentsScrollable = find.descendant(
      of: find.byKey(const ValueKey('comments-list')),
      matching: find.byType(Scrollable),
    );
    final commentsPosition = tester
        .state<ScrollableState>(commentsScrollable)
        .position;
    commentsPosition.jumpTo(commentsPosition.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(repository.commentCursors, [null, '10']);
    expect(find.text('Prayer comment 11'), findsOneWidget);
  });

  testWidgets('first two navigation items switch their matching pages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: _FakePostsRepository(),
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-0')));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('opening the Ycoin balance shows live operation rewards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: _FakePostsRepository(),
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ycoin-balance')));
    await tester.pumpAndSettle();

    expect(
      find.text('Yield to God Coins (YC)\nHistorical record'),
      findsOneWidget,
    );
    expect(find.text('📝 create post'), findsOneWidget);
    expect(find.text('🙏 Amen'), findsOneWidget);
    expect(find.text('💬 Comment'), findsOneWidget);
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('+0.2'), findsOneWidget);
  });

  testWidgets('Ycoin balance remains tappable when balance request fails', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: _FakePostsRepository(),
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _UnavailableBalanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ycoin-balance')));
    await tester.pumpAndSettle();

    expect(
      find.text('Yield to God Coins (YC)\nHistorical record'),
      findsOneWidget,
    );
    expect(find.text('No Ycoin records yet.'), findsOneWidget);
  });

  testWidgets('Ycoin balance stays visible during operations that do affect it', (
    WidgetTester tester,
  ) async {
    final ycoin = _RefreshingBalanceRepository();
    final posts = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'balance-refresh-post',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: posts,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: ycoin,
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    // Verify initial balance is displayed
    expect(find.text('12.75'), findsOneWidget);
    
    // Tap on the amen button (this SHOULD trigger Ycoin refresh now)
    await tester.tap(
      find.byKey(const ValueKey('amen-post-balance-refresh-post')),
    );
    await tester.pumpAndSettle();

    // Verify that Ycoin was loaded twice (initial + after amen)
    expect(ycoin.calls, 2);
    
    // Verify the balance is still visible and updated
    expect(find.text('12.75'), findsOneWidget);
    
    // Verify that we can still tap on the balance and it's functional
    await tester.tap(find.byKey(const ValueKey('ycoin-balance')));
    await tester.pumpAndSettle();
    
    // The balance should still be visible
    expect(find.text('12.75'), findsOneWidget);
  });

  testWidgets('notifications page matches the empty state and unread filter', (
    WidgetTester tester,
  ) async {
    final social = _FakeSocialRepository()
      ..unreadCount = 1
      ..notifications.addAll([
        SocialNotification(
          notificationId: 'notification-1',
          message: 'A friend commented on your post',
          notificationType: 'comment',
          isRead: false,
          createdAt: DateTime.utc(2026, 11, 9, 7, 23),
        ),
        SocialNotification(
          notificationId: 'notification-2',
          message: 'A friend liked your post',
          notificationType: 'amen',
          isRead: true,
          createdAt: DateTime.utc(2026, 11, 8, 7, 23),
        ),
      ]);
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: _FakePostsRepository(),
          socialRepository: social,
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('🔔 Notifications'), findsOneWidget);
    expect(social.notificationQueries.first, (null, 50, false));
    expect(
      tester.getCenter(find.byKey(const ValueKey('notifications-back'))).dy,
      tester.getCenter(find.byKey(const ValueKey('notifications-title'))).dy,
    );
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unread (1)'), findsOneWidget);
    expect(find.text('A friend commented on your post'), findsOneWidget);
    expect(find.text('A friend liked your post'), findsOneWidget);

    await tester.tap(find.text('Unread (1)'));
    await tester.pumpAndSettle();
    expect(social.notificationQueries.last, (null, 50, true));
    expect(
      find.byKey(const ValueKey('notification-notification-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('notification-notification-2')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('notification-notification-1')));
    await tester.pumpAndSettle();
    expect(social.unreadCount, 0);
    expect(find.text('Unread (0)'), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('notifications paginate in batches of fifty', (
    WidgetTester tester,
  ) async {
    final social = _FakeSocialRepository()
      ..notifications.addAll(
        List.generate(
          51,
          (index) => SocialNotification(
            notificationId: 'notification-${index + 1}',
            message: 'Notification ${index + 1}',
            notificationType: 'comment',
            isRead: true,
            createdAt: DateTime.utc(2026, 11, 9),
          ),
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: _FakePostsRepository(),
          socialRepository: social,
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notifications-button')));
    await tester.pumpAndSettle();

    expect(find.text('Notification 1'), findsOneWidget);
    expect(find.text('Notification 51'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('notifications-next-page')));
    await tester.pumpAndSettle();

    expect(find.text('Notification 51'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(social.notificationQueries.last, ('50', 50, false));
    await tester.tap(find.byKey(const ValueKey('notifications-previous-page')));
    await tester.pumpAndSettle();
    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Notification 1'), findsOneWidget);
  });

  testWidgets('publishing a prayer sends it and shows it in the feed', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {
            'displayName': 'Prayer User',
            'email': 'user@example.com',
          },
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create text post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('post-title')),
      'A test prayer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('post-content')),
      'Please pray for my family.',
    );
    await tester.tap(find.byKey(const ValueKey('publish-post')));
    await tester.pumpAndSettle();

    expect(repository.publishedTitle, 'A test prayer');
    expect(repository.publishedContent, 'Please pray for my family.');
    expect(repository.publishedCategory, 'Personal & Family');
    expect(repository.publishedPrivacy, 'public');
    expect(find.text('A test prayer'), findsOneWidget);
    expect(find.text('Please pray for my family.'), findsOneWidget);
  });

  testWidgets('post Amen, comments, and Witness use the repository', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'post-1',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User', 'userId': 'user-id'},
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.feedPageSizes, [10]);
    expect(find.byKey(const ValueKey('share-post-post-1')), findsOneWidget);
    final amenButton = find.byKey(const ValueKey('amen-post-post-1'));
    await tester.ensureVisible(amenButton);
    await tester.tap(amenButton);
    await tester.pumpAndSettle();
    expect(repository.amenCalls, 1);
    expect(find.text('AMENED (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('comment-post-post-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comments-panel')), findsOneWidget);
    expect(find.text('PRAY FOR ME (0)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('comment-input')),
      'I am praying for you.',
    );
    await tester.tap(find.byKey(const ValueKey('send-comment')));
    await tester.pumpAndSettle();
    expect(repository.commentedPostId, 'post-1');
    expect(repository.commentContent, 'I am praying for you.');
    expect(find.text('PRAY FOR ME (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('witness-post-post-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('witness-panel')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('witness-input')),
      'A testimony.',
    );
    await tester.tap(find.byKey(const ValueKey('submit-witness')));
    await tester.pumpAndSettle();
    expect(repository.witnessedPostId, 'post-1');
    expect(repository.witnessContent, 'A testimony.');
  });

  testWidgets('only the author can submit one testimony per post', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'post-1',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Another User', 'userId': 'another-user'},
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('witness-post-post-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('witness-panel')), findsNothing);
    expect(repository.witnessedPostId, isNull);
  });

  testWidgets('WITNESSED opens the existing testimony', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'post-with-testimony',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
          witnessed: true,
        ),
      )
      ..witnesses.add(
        PostWitness(
          witnessId: 'witness-1',
          postId: 'post-with-testimony',
          userId: 'user-id',
          content: 'I am trusting God through this season.',
          displayName: 'Post Author',
          avatarUrl: null,
          createdAt: DateTime.utc(2026, 11, 9),
          amenCount: 0,
          amened: false,
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Post Author', 'userId': 'user-id'},
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('witness-post-post-with-testimony')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('witness-panel')), findsOneWidget);
    expect(find.text('I am trusting God through this season.'), findsOneWidget);
    expect(repository.witnessedPostId, isNull);
  });

  testWidgets('comment Amen uses the comment target endpoint', (
    WidgetTester tester,
  ) async {
    final repository = _FakePostsRepository()
      ..posts.add(
        _post(
          postId: 'post-with-comment',
          content: 'Please pray for me.',
          category: 'Personal & Family',
          privacy: 'public',
        ),
      )
      ..comments.add(
        PostComment(
          commentId: 'comment-1',
          content: 'I am praying.',
          userId: 'user-id',
          displayName: 'Prayer Friend',
          avatarUrl: null,
          createdAt: DateTime.utc(2026, 11, 9),
          amenCount: 0,
          amened: false,
        ),
      );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Prayer User'},
          postsRepository: repository,
          socialRepository: _FakeSocialRepository(),
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('comment-post-post-with-comment')),
    );
    await tester.pumpAndSettle();
    final amenComment = find.byKey(const ValueKey('amen-comment-comment-1'));
    await tester.ensureVisible(amenComment);
    await tester.pumpAndSettle();
    await tester.tap(amenComment);
    await tester.pumpAndSettle();

    expect(repository.commentAmenCalls, 1);
    expect(find.text('AMEN (1)'), findsOneWidget);
  });

  testWidgets('two mock accounts can send and accept a friend invitation', (
    WidgetTester tester,
  ) async {
    final social = _FakeSocialRepository();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: const {'displayName': 'Account A'},
          postsRepository: _FakePostsRepository(),
          socialRepository: social,
          ycoinRepository: _FakeYcoinRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'account-b');
    await tester.tap(find.byKey(const ValueKey('search-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-account-b')));
    await tester.pumpAndSettle();
    expect(social.invitationsSent, ['account-b']);

    social.activeAccount = 'account-b';
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Accept invitation'));
    await tester.pumpAndSettle();

    expect(social.invitationResponses, [('invitation-a-b', true)]);
    expect(social.friendsByAccount['account-a'], hasLength(1));
    expect(social.friendsByAccount['account-b'], hasLength(1));
  });
}
