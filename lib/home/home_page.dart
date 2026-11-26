import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../models/prayer_post.dart';
import '../pages/friend_search_page.dart';
import '../pages/notification_page.dart';
import '../pages/profile_page.dart';
import '../pages/tribe_page.dart';
import '../pages/ycoin_transactions_page.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/media_service.dart';
import '../services/notifications_service.dart';
import '../services/posts_service.dart' as posts;
import '../services/profile_service.dart';
import '../services/witness_service.dart';
import '../services/ycoin_service.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/post_edit_form.dart';
import '../widgets/prayer_composer.dart';
import '../widgets/witness_composer_sheet.dart';
import '../widgets/ycoin_display.dart';

enum _FeedTab { posts, witnesses }

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiClient apiClient;
  final AuthService authService;
  final YCoinService yCoinService;
  final WitnessService witnessService;
  final MediaService mediaService;
  final NotificationsService notificationsService;
  final posts.PostsRepository postsRepository;
  final Future<void> Function() onLogout;

  const HomePage({
    super.key,
    required this.user,
    required this.apiClient,
    required this.authService,
    required this.yCoinService,
    required this.witnessService,
    required this.mediaService,
    required this.notificationsService,
    required this.postsRepository,
    required this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _categories = [
    'Personal & Family',
    'Church & Ministry',
    'Kingdom Prayer',
    'Tribe Prayer',
  ];
  static const _tribeNames = {
    1: 'Judah',
    2: 'Reuben',
    3: 'Gad',
    4: 'Asher',
    5: 'Naphtali',
    6: 'Manasseh',
    7: 'Simeon',
    8: 'Levi',
    9: 'Issachar',
    10: 'Zebulun',
    11: 'Joseph',
    12: 'Benjamin',
  };

  final List<PrayerPost> _posts = [];
  final List<WitnessEntry> _witnesses = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late final FriendsService _friendsService = FriendsService(
    widget.apiClient.dio,
  );

  _FeedTab _feedTab = _FeedTab.posts;
  late final ProfileService _profileService = ProfileService(
    widget.apiClient.dio,
  );
  String? _selectedCategory = _categories.first;
  String _postCategory = _categories.first;
  String _postPrivacy = 'public';
  String? _createMode;
  String? _nextCursor;
  String? _errorMessage;
  String? _yCoinBalance;
  List<String?> _pageStartCursors = [null];
  int _currentPageIndex = 0;
  int _selectedIndex = 0;
  int _unreadCount = 0;
  int _feedRequestToken = 0;
  String? _notificationError;
  bool _isLoading = false;
  bool _isSubmittingPost = false;
  bool _hasMore = true;

  String get _userId =>
      (widget.user['id'] ?? widget.user['userId'] ?? '').toString();

  String get _displayName {
    final email = widget.user['email']?.toString();
    return (widget.user['displayName'] ??
            widget.user['name'] ??
            widget.user['username'] ??
            email?.split('@').first ??
            'Guest')
        .toString();
  }

  int? get _tribeCode => int.tryParse(
    (widget.user['tribe'] ?? widget.user['tribeCode'] ?? '').toString(),
  );

  String get _tribeName {
    final code = _tribeCode;
    return code == null ? 'NOT TRIBE' : _tribeNames[code] ?? 'Unknown';
  }

  String? get _tribeIconPath {
    final name = _tribeNames[_tribeCode];
    return name == null
        ? null
        : 'assets/images/tribes/${name.toLowerCase()}.png';
  }

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadYCoinBalance();
    _loadUnreadCount();
  }

  Future<void> _loadFeed({
    bool refresh = false,
    String? pageCursor,
    bool usePageCursor = false,
    bool replacePage = false,
  }) async {
    if (_isLoading && !refresh) return;
    if (refresh) {
      _feedRequestToken++;
      _isLoading = false;
      _pageStartCursors = [null];
      _currentPageIndex = 0;
      _nextCursor = null;
      _hasMore = true;
      if (_feedTab == _FeedTab.posts) {
        _posts.clear();
      } else {
        _witnesses.clear();
      }
    }

    final tab = _feedTab;
    final category = _selectedCategory;
    final cursor = usePageCursor ? pageCursor : _nextCursor;
    final requestToken = ++_feedRequestToken;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (tab == _FeedTab.posts) {
        final page = await widget.postsRepository.getFeed(
          category: category,
          cursor: cursor,
          pageSize: 25,
        );
        if (!mounted || requestToken != _feedRequestToken) return;
        setState(() {
          if (replacePage) _posts.clear();
          _posts.addAll(page.items.map(_toDisplayPost));
          _nextCursor = page.nextCursor;
          _hasMore = page.nextCursor != null && page.nextCursor!.isNotEmpty;
          _isLoading = false;
        });
      } else {
        final page = await widget.witnessService.getFeed(
          category: category,
          cursor: cursor,
          pageSize: 25,
        );
        if (!mounted || requestToken != _feedRequestToken) return;
        setState(() {
          if (replacePage) _witnesses.clear();
          _witnesses.addAll(page.items);
          _nextCursor = page.nextCursor;
          _hasMore = page.nextCursor != null && page.nextCursor!.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted || requestToken != _feedRequestToken) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  PrayerPost _toDisplayPost(posts.PrayerPost post) {
    return PrayerPost(
      postId: post.postId,
      userId: post.userId,
      authorName: post.author?.displayName,
      avatarUrl: post.author?.avatarUrl == null
          ? null
          : _resolveMediaUrl(post.author!.avatarUrl!),
      title: post.title,
      content: post.content,
      category: post.category,
      privacy: post.privacy,
      createdAt: post.createdAt,
      amenCount: post.amenCount,
      commentCount: post.commentCount,
      witnessCount: 0,
      amened: post.amened,
      witnessed: post.witnessed,
    );
  }

  Future<void> _changePage(int direction) async {
    if (_isLoading) return;
    final nextIndex = _currentPageIndex + direction;
    if (nextIndex < 0) return;
    if (direction > 0) {
      if (!_hasMore || _nextCursor == null) return;
      if (_pageStartCursors.length == nextIndex) {
        _pageStartCursors.add(_nextCursor);
      }
      if (nextIndex >= _pageStartCursors.length) return;
    } else if (nextIndex >= _pageStartCursors.length) {
      return;
    }

    final cursor = _pageStartCursors[nextIndex];
    setState(() {
      _currentPageIndex = nextIndex;
      _nextCursor = null;
      _hasMore = true;
      _errorMessage = null;
      if (_feedTab == _FeedTab.posts) {
        _posts.clear();
      } else {
        _witnesses.clear();
      }
    });
    await _loadFeed(pageCursor: cursor, usePageCursor: true, replacePage: true);
  }

  void _changeFeedTab(_FeedTab tab) {
    if (_feedTab == tab) return;
    _feedRequestToken++;
    setState(() {
      _feedTab = tab;
      _isLoading = false;
      _hasMore = true;
      _nextCursor = null;
      _pageStartCursors = [null];
      _currentPageIndex = 0;
      _errorMessage = null;
      _posts.clear();
      _witnesses.clear();
    });
    _loadFeed();
  }

  void _changeCategory(String? category) {
    if (_selectedCategory == category) return;
    _feedRequestToken++;
    setState(() {
      _selectedCategory = category;
      _isLoading = false;
      _hasMore = true;
      _nextCursor = null;
      _pageStartCursors = [null];
      _currentPageIndex = 0;
      _errorMessage = null;
      _posts.clear();
      _witnesses.clear();
    });
    _loadFeed();
  }

  Future<void> _loadYCoinBalance() async {
    try {
      final balance = await widget.yCoinService.getBalance();
      if (!mounted) return;
      setState(() => _yCoinBalance = balance.balance);
    } catch (error) {
      if (!mounted) return;
      setState(() => _yCoinBalance = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await widget.notificationsService.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
          _notificationError = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _notificationError = error.toString());
    }
  }

  Future<void> _openNotifications() async {
    if (_notificationError != null) {
      _showMessage(_notificationError!);
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationPage(notificationsService: widget.notificationsService),
      ),
    );
    _loadUnreadCount();
  }

  Future<void> _openYCoinHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YCoinTransactionsPage(
          yCoinService: widget.yCoinService,
          onNavigate: (index) {
            Navigator.of(context).pop();
            _onNavigationSelected(index);
          },
        ),
      ),
    );
    _loadYCoinBalance();
  }

  Future<posts.AmenResult> _togglePostAmen(PrayerPost post) async {
    final result = await widget.postsRepository.toggleAmen(
      targetId: post.postId,
      targetType: 'post',
    );
    await _loadYCoinBalance();
    return result;
  }

  Future<bool> _publishPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showMessage('Please enter post content.');
      return false;
    }
    if (content.length > 500) {
      _showMessage('Post content cannot exceed 500 characters.');
      return false;
    }

    setState(() => _isSubmittingPost = true);
    try {
      final post = await widget.postsRepository.createPost(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        content: content,
        category: _postCategory,
        privacy: _postPrivacy,
      );
      if (!mounted) return false;
      setState(() {
        _feedRequestToken++;
        _createMode = null;
        _isLoading = false;
        _isSubmittingPost = false;
        _feedTab = _FeedTab.posts;
        _selectedIndex = 0;
        _selectedCategory = post.category;
        _pageStartCursors = [null];
        _currentPageIndex = 0;
        _nextCursor = null;
        _hasMore = true;
        _posts.clear();
        _witnesses.clear();
        _contentController.clear();
        _titleController.clear();
      });
      await Future.wait([_loadYCoinBalance(), _loadFeed(refresh: true)]);
      _showMessage('Post published.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _isSubmittingPost = false);
      _showError(error);
      return false;
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProfilePage(user: widget.user, profileService: _profileService),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openTribe() async {
    final code = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => TribePage(
          selectedTribeCode: _tribeCode,
          profileService: _profileService,
        ),
      ),
    );
    if (!mounted || code == null) return;
    setState(() {
      widget.user['tribe'] = code;
      widget.user['tribeCode'] = code;
    });
    await _loadFeed(refresh: true);
  }

  Future<void> _openComposer() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrayerComposer(
          hasTribe: _tribeCode != null,
          onNavigate: _onNavigationSelected,
          onPublish: (draft) async {
            _titleController.text = draft.title;
            _contentController.text = draft.content;
            _postCategory = draft.category;
            _postPrivacy = draft.privacy;
            return _publishPost();
          },
        ),
      ),
    );
  }

  void _onNavigationSelected(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedIndex = 0);
        _changeFeedTab(_FeedTab.posts);
        break;
      case 1:
        setState(() => _selectedIndex = 1);
        _changeFeedTab(_FeedTab.witnesses);
        break;
      case 2:
        _openComposer();
        break;
      case 3:
        setState(() {
          _selectedIndex = 3;
          _createMode = null;
        });
        break;
      default:
        setState(() => _selectedIndex = index);
        _showMessage('This feature is not available yet.');
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _feedRequestToken++;
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: appBackground,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: _createMode != null || _selectedIndex == 3
            ? AppBar(
                backgroundColor: appBackground,
                foregroundColor: Colors.white,
                title: Text(_createMode == null ? '' : 'Create post'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_selectedIndex == 3 || _createMode != null) {
                      setState(() {
                        _selectedIndex = 0;
                        _createMode = null;
                      });
                    }
                  },
                ),
              )
            : null,
        body: _createMode != null
            ? _buildCreatePostScreen()
            : _selectedIndex == 3
            ? FriendSearchPage(friendsService: _friendsService)
            : SafeArea(top: true, bottom: false, child: _buildFeed()),
        bottomNavigationBar: _createMode == null
            ? AppBottomNavigationBar(
                selectedIndex: _selectedIndex,
                onSelected: _onNavigationSelected,
              )
            : null,
      ),
    );
  }

  Widget _buildFeed() {
    final itemCount = _feedTab == _FeedTab.posts
        ? _posts.length
        : _witnesses.length;
    return Column(
      children: [
        _buildHomeHeader(),
        const Divider(height: 1, color: Colors.white24),
        _buildFeedFilters(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadFeed(refresh: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: itemCount + 1,
              itemBuilder: (context, index) {
                if (index == itemCount) return _buildFeedFooter(itemCount);
                return _feedTab == _FeedTab.posts
                    ? _buildPostCard(_posts[index])
                    : _buildWitnessCard(_witnesses[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeHeader() {
    final avatar =
        widget.user['avatarUrl'] ??
        widget.user['avatar_url'] ??
        widget.user['avatar'];
    final avatarUrl = avatar is String && avatar.isNotEmpty
        ? _resolveMediaUrl(avatar)
        : null;
    final tribeIconPath = _tribeIconPath;

    return Container(
      color: const Color(0xFF2D3656),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openProfile,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF667EEA),
                          backgroundImage: avatarUrl == null
                              ? null
                              : NetworkImage(avatarUrl),
                          child: avatarUrl == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildNotificationButton(),
              const SizedBox(width: 6),
              YCoinDisplay(
                balance: _yCoinBalance ?? '--',
                onTap: _openYCoinHistory,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openTribe,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tribeIconPath == null
                              ? const Color(0xFFD9D9D9)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B6F47),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: tribeIconPath == null
                            ? null
                            : Image.asset(tribeIconPath, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _tribeName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildHeaderAction(
                tooltip: 'Family & Community',
                onTap: () => _onNavigationSelected(3),
                child: Image.asset(
                  'assets/icons/mdi_family.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              _buildHeaderAction(
                tooltip: 'Sign out',
                onTap: _onLogout,
                width: 66,
                child: const Text(
                  'LOG OUT',
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFF8B6F47),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _openNotifications,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4444),
                      border: Border.all(
                        color: const Color(0xFF2D3656),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
    double width = 42,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: width,
        height: 42,
        child: Material(
          color: appCream,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedFilters() {
    return Column(
      children: [
        SizedBox(
          height: 106,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (final category in _categories)
                  _categoryChip(category, category, _categoryIcon(category)),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.white54),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _feedTabButton(
                  label: 'Original Post',
                  tab: _FeedTab.posts,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _feedTabButton(
                  label: 'Witness Wall',
                  tab: _FeedTab.witnesses,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white54),
      ],
    );
  }

  Widget _categoryChip(String label, String category, String iconPath) {
    final selected = _selectedCategory == category;
    final labelColor = selected
        ? const Color(0xFFFFDE97)
        : const Color(0xFFF4E4C1);
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeCategory(category),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF9EC) : appCream,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(color: const Color(0xFF6B4E2E), width: 2)
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(
                iconPath,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            Icon(Icons.arrow_drop_up, color: labelColor, size: 14),
            Container(
              width: double.infinity,
              height: 22,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5D4E37),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryIcon(String category) {
    return switch (category) {
      'Personal & Family' => 'assets/icons/family_and_personal.png',
      'Church & Ministry' => 'assets/icons/church.png',
      'Kingdom Prayer' => 'assets/icons/kingdom.png',
      'Tribe Prayer' => 'assets/icons/tribe.png',
      _ => 'assets/icons/Category.png',
    };
  }

  Widget _feedTabButton({required String label, required _FeedTab tab}) {
    final selected = _feedTab == tab;
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: () => _changeFeedTab(tab),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? appGold : appCream,
          foregroundColor: Colors.black87,
          side: const BorderSide(color: appYellow, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildFeedFooter(int itemCount) {
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
            Text(_errorMessage!, textAlign: TextAlign.center),
            TextButton(
              onPressed: () {
                if (itemCount == 0) {
                  _loadFeed(
                    pageCursor: _pageStartCursors[_currentPageIndex],
                    usePageCursor: true,
                    replacePage: true,
                  );
                } else {
                  _loadFeed();
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (itemCount == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
        child: Column(
          children: [
            const Text('No content yet', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            _buildPageNavigation(),
          ],
        ),
      );
    }
    return _buildPageNavigation();
  }

  Widget _buildPageNavigation() {
    return Column(
      children: [
        const Divider(
          height: 1,
          thickness: 1.5,
          color: Colors.black,
          indent: 4,
          endIndent: 4,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _currentPageIndex == 0 || _isLoading
                    ? null
                    : () => _changePage(-1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                  side: BorderSide.none,
                  backgroundColor: const Color(0xFF4CAF50),
                  disabledBackgroundColor: const Color(0xFF9E9E9E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: const Text('← Previous'),
              ),
              Text(
                'Page ${_currentPageIndex + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              OutlinedButton(
                onPressed: !_hasMore || _isLoading
                    ? null
                    : () => _changePage(1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white54,
                  side: BorderSide.none,
                  backgroundColor: const Color(0xFF4CAF50),
                  disabledBackgroundColor: const Color(0xFF9E9E9E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Next →'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(PrayerPost post) {
    return _buildPrayerCard(post);
  }

  Widget _buildPrayerCard(PrayerPost post, {Widget? embeddedWitness}) {
    final isPostAuthor = _userId.isNotEmpty && _userId == post.userId;
    return PostCard(
      key: ValueKey(post.postId),
      post: post,
      isPostAuthor: isPostAuthor,
      onLike: () => _togglePostAmen(post),
      onCommentAdded: _loadYCoinBalance,
      commentsBuilder: (onClose, onCreated) => CommentsPanel(
        postsRepository: widget.postsRepository,
        postId: post.postId,
        initialCommentCount: post.commentCount,
        onCommentAdded: onCreated,
        onClose: onClose,
      ),
      witnessComposerBuilder: isPostAuthor
          ? (onClose) => WitnessComposer(
              postId: post.postId,
              witnessService: widget.witnessService,
              mediaService: widget.mediaService,
              onWitnessCreated: () async {
                await _loadYCoinBalance();
                _changeFeedTab(_FeedTab.witnesses);
              },
              onCancel: onClose,
            )
          : null,
      editFormBuilder: isPostAuthor
          ? (onClose) => PostEditForm(
              post: post,
              postsRepository: widget.postsRepository,
              onSaved: () async {
                await _loadFeed(refresh: true);
                _showMessage('Post updated');
              },
              onCancel: onClose,
            )
          : null,
      embeddedWitness: embeddedWitness,
    );
  }

  Widget _buildWitnessCard(WitnessEntry witness) {
    final original = witness.originalPost;
    if (original != null) {
      return KeyedSubtree(
        key: ValueKey('witness-${witness.witnessId}'),
        child: _buildPrayerCard(
          _toDisplayPost(original),
          embeddedWitness: _buildWitnessPreview(witness),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: _buildWitnessPreview(witness),
    );
  }

  Widget _buildWitnessPreview(WitnessEntry witness) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: appCream,
        border: Border.all(color: appYellow, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF9DC8FF),
                backgroundImage: witness.author?.avatarUrl == null
                    ? null
                    : NetworkImage(
                        _resolveMediaUrl(witness.author!.avatarUrl!),
                      ),
                child: witness.author?.avatarUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF2874D0))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      witness.author?.displayName ?? 'User',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatRelativeDate(witness.createdAt),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(witness.content, style: const TextStyle(fontSize: 17)),
          if (witness.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _resolveMediaUrl(witness.imageUrl!),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(ApiClient.baseUrl).resolve(value).toString();
  }

  String _formatRelativeDate(DateTime date) {
    final duration = DateTime.now().difference(date.toLocal());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes} minutes ago';
    if (duration.inDays < 1) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Widget _buildCreatePostScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLength: 500,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Content',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _postCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _categories
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _postCategory = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _postPrivacy,
            decoration: const InputDecoration(
              labelText: 'Privacy',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(value: 'family', child: Text('Family')),
              DropdownMenuItem(value: 'tribe', child: Text('Tribe')),
              DropdownMenuItem(value: 'individual', child: Text('Only me')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _postPrivacy = value);
            },
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSubmittingPost ? null : _publishPost,
            icon: _isSubmittingPost
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Publish post'),
          ),
        ],
      ),
    );
  }

  Future<void> _onLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    try {
      await widget.onLogout();
    } catch (error) {
      _showError(error);
    }
  }
}
