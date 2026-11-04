import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/main.dart';
import 'package:pray_like_incense/services/posts_service.dart';

class _FakePostsRepository implements PostsRepository {
  final List<PrayerPost> posts = [];
  String? publishedContent;
  String? publishedTitle;
  String? publishedCategory;
  String? publishedPrivacy;

  @override
  Future<PostFeedPage> getFeed({
    required String category,
    String? cursor,
    int pageSize = 20,
  }) async {
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
}

PrayerPost _post({
  required String postId,
  String? title,
  required String content,
  required String category,
  required String privacy,
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
    witnessed: false,
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
        ),
      ),
    );

    expect(find.byKey(const ValueKey('profile-avatar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-bottom-navigation')),
      findsOneWidget,
    );
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
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getTopLeft(bottomNavigation).dy, initialPosition.dy);
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
}
