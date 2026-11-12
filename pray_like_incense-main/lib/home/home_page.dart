import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../auth/login_page.dart' hide cleanError;
import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../services/posts_service.dart';
import '../services/social_service.dart';
import '../services/ycoin_service.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'ycoin_history_page.dart';

const Color appBackground = Color(0xFF2D395D);
const Color appSurface = Color(0xFF414D70);
const Color appDarkSurface = Color(0xFF191A31);
const Color appSelected = Color(0xFFFFDA82);
const Color appIconBrown = Color(0xFF76502D);

enum _PostPanel { comments, witness }

class _PostInteractionPanel extends StatefulWidget {
  final PrayerPost post;
  final bool isPostAuthor;
  final Future<void> Function()? onAmen;
  final Future<PostCommentPage> Function(String? cursor) onLoadComments;
  final Future<List<PostWitness>> Function() onLoadWitnesses;
  final Future<PostEngagement> Function(String commentId) onAmenComment;
  final Future<void> Function(String content) onSendComment;
  final Future<void> Function(String content) onSendWitness;
  final Future<void> Function() onYcoinUpdate;

  const _PostInteractionPanel({
    super.key,
    required this.post,
    required this.isPostAuthor,
    required this.onAmen,
    required this.onLoadComments,
    required this.onLoadWitnesses,
    required this.onAmenComment,
    required this.onSendComment,
    required this.onSendWitness,
    required this.onYcoinUpdate,
  });

  @override
  State<_PostInteractionPanel> createState() => _PostInteractionPanelState();
}

class _PostInteractionPanelState extends State<_PostInteractionPanel> {
  final _commentController = TextEditingController();
  final _witnessController = TextEditingController();
  _PostPanel? _activePanel;
  List<PostComment> _comments = [];
  List<PostWitness> _witnesses = [];
  String? _nextCommentCursor;
  String? _commentLoadError;
  bool _isLoadingComments = false;
  bool _isLoadingMoreComments = false;
  bool _isLoadingWitnesses = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    _witnessController.dispose();
    super.dispose();
  }

  Future<void> _togglePanel(_PostPanel panel) async {
    if (_activePanel == panel) {
      setState(() {
        _activePanel = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _activePanel = panel;
      _error = null;
    });
    if (panel == _PostPanel.comments) {
      await _refreshComments();
    } else if (panel == _PostPanel.witness) {
      // Always allow toggling witness panel, regardless of authorship or witnessed status
      await _refreshWitnesses();
    }
  }

  Future<void> _refreshComments({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMoreComments || _nextCommentCursor == null)) {
      return;
    }
    final cursor = loadMore ? _nextCommentCursor : null;
    setState(() {
      _commentLoadError = null;
      if (loadMore) {
        _isLoadingMoreComments = true;
      } else {
        _isLoadingComments = true;
        _commentLoadError = null;
      }
    });
    try {
      final page = await widget.onLoadComments(cursor);
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          final existingIds = _comments
              .map((comment) => comment.commentId)
              .toSet();
          _comments.addAll(
            page.items.where((comment) => existingIds.add(comment.commentId)),
          );
        } else {
          _comments = page.items;
        }
        _nextCommentCursor = page.nextCursor;
        _isLoadingComments = false;
        _isLoadingMoreComments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _commentLoadError = cleanError(error);
        _isLoadingComments = false;
        _isLoadingMoreComments = false;
      });
    }
  }

  Future<void> _refreshWitnesses() async {
    setState(() {
      _isLoadingWitnesses = true;
      _error = null;
    });
    try {
      final witnesses = await widget.onLoadWitnesses();
      if (!mounted) return;
      setState(() {
        _witnesses = witnesses;
        _isLoadingWitnesses = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(error);
        _isLoadingWitnesses = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || content.length > 2000) {
      setState(
        () => _error = 'Comment must be between 1 and 2,000 characters.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSendComment(content);
      if (!mounted) return;
      _commentController.clear();
      await _refreshComments();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitWitness() async {
    final content = _witnessController.text.trim();
    if (content.isEmpty || content.length > 5000) {
      setState(
        () => _error = 'Testimony must be between 1 and 5,000 characters.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.onSendWitness(content);
      if (!mounted) return;
      _witnessController.clear();
      setState(() => _activePanel = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _amenComment(PostComment comment) async {
    try {
      final engagement = await widget.onAmenComment(comment.commentId);
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map(
              (item) => item.commentId == comment.commentId
                  ? item.copyWith(
                      amenCount: engagement.amenCount,
                      amened: engagement.amened,
                    )
                  : item,
            )
            .toList();
      });
      widget.onYcoinUpdate();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _actionButton(
              key: ValueKey('amen-post-${widget.post.postId}'),
              label:
                  '${widget.post.amened ? 'AMENED' : 'AMEN'} '
                  '(${widget.post.amenCount})',
              selected: widget.post.amened,
              onTap: widget.onAmen == null ? null : () => widget.onAmen!(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              key: ValueKey('comment-post-${widget.post.postId}'),
              label: 'PRAY FOR ME (${widget.post.commentCount})',
              selected: _activePanel == _PostPanel.comments,
              onTap: () => _togglePanel(_PostPanel.comments),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              key: ValueKey('witness-post-${widget.post.postId}'),
              label: widget.post.witnessed ? '✨ WITNESSED' : 'WITNESS',
              selected: widget.post.witnessed,
              active: _activePanel == _PostPanel.witness,
              onTap: () => _togglePanel(_PostPanel.witness),
            ),
          ),
        ],
      ),
      if (_activePanel == _PostPanel.comments) ...[
        const SizedBox(height: 14),
        _buildCommentsPanel(),
      ] else if (_activePanel == _PostPanel.witness) ...[
        const SizedBox(height: 14),
        _buildWitnessPanel(),
      ],
    ],
  );

  Widget _actionButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    final color = selected
        ? appSelected
        : active
        ? const Color(0xFFD0D0D0)
        : const Color(0xFFD9D9D9);
    return Material(
      key: key,
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: appSelected, width: 2) : null,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x40FFDA82),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? appIconBrown : const Color(0xFF676767),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsPanel() => Container(
    key: const ValueKey('comments-panel'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F8FC),
      border: Border.all(color: const Color(0xFF47A2E3), width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('comment-input'),
          controller: _commentController,
          maxLength: 2000,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Write your comment...',
            hintStyle: const TextStyle(color: Color(0xFF999999)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
            ),
            counterText: '',
          ),
        ),
        if (_error != null) _panelError,
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _panelButton(
                key: const ValueKey('send-comment'),
                label: 'Pray For You',
                color: const Color(0xFF91C4F1),
                onTap: _isSubmitting ? null : _submitComment,
                loading: _isSubmitting,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _panelButton(
                label: 'Cancel',
                color: const Color(0xFFE0E0E0),
                onTap: _isSubmitting
                    ? null
                    : () => setState(() {
                        _activePanel = null;
                        _error = null;
                      }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '💬 Prayers (${widget.post.commentCount})',
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(height: 18),
        if (_isLoadingComments)
          const Center(child: CircularProgressIndicator())
        else if (_commentLoadError != null && _comments.isEmpty)
          Text(_commentLoadError!, style: const TextStyle(color: Colors.red))
        else if (_comments.isEmpty)
          const SizedBox(
            width: double.infinity,
            child: Text(
              'No prayers yet.',
              style: TextStyle(color: Color(0xFF777777)),
            ),
          )
        else ...[
          if (_commentLoadError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _commentLoadError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          SizedBox(
            height: 320,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 100 &&
                    _nextCommentCursor != null &&
                    _commentLoadError == null) {
                  _refreshComments(loadMore: true);
                }
                return false;
              },
              child: ListView.builder(
                key: const ValueKey('comments-list'),
                itemCount:
                    _comments.length +
                    (_nextCommentCursor != null ||
                            _isLoadingMoreComments ||
                            _commentLoadError != null
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < _comments.length) {
                    return _commentTile(_comments[index]);
                  }
                  if (_isLoadingMoreComments) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_commentLoadError != null) {
                    return TextButton(
                      onPressed: () => _refreshComments(loadMore: true),
                      child: const Text('Retry loading comments'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _commentTile(PostComment comment) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PostAvatar(avatarUrl: comment.avatarUrl, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.displayName,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(comment.createdAt),
                      style: const TextStyle(color: gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              comment.content,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 15),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),
          SizedBox(
            width: 110,
            child: _actionButton(
              key: ValueKey('amen-comment-${comment.commentId}'),
              label: 'AMEN (${comment.amenCount})',
              selected: comment.amened,
              onTap: () => _amenComment(comment),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildWitnessPanel() => widget.post.witnessed
      ? _buildWitnessListPanel()
      : _buildWitnessFormPanel();

  Widget _buildWitnessListPanel() => Container(
    key: const ValueKey('witness-panel'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEF7),
      border: Border.all(color: const Color(0xFFFFD600), width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: _isLoadingWitnesses
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        : _error != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: _refreshWitnesses,
                child: const Text('Retry'),
              ),
            ],
          )
        : _witnesses.isEmpty
        ? const Text(
            'No testimonies yet.',
            style: TextStyle(color: Color(0xFF666666)),
          )
        : Column(
            children: _witnesses
                .map(
                  (witness) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PostAvatar(avatarUrl: witness.avatarUrl, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                witness.displayName,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(witness.createdAt),
                                style: const TextStyle(
                                  color: gray,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                witness.content,
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );

  Widget _buildWitnessFormPanel() => Container(
    key: const ValueKey('witness-panel'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFEF7),
      border: Border.all(color: const Color(0xFFFFD600), width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        TextField(
          key: const ValueKey('witness-input'),
          controller: _witnessController,
          maxLength: 5000,
          maxLines: 5,
          minLines: 4,
          decoration: InputDecoration(
            hintText: 'Share your testimony...',
            hintStyle: const TextStyle(color: Color(0xFF999999)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
            ),
            counterText: '',
          ),
        ),
        if (_error != null) _panelError,
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _panelButton(
            key: const ValueKey('submit-witness'),
            label: '✨ Submit Testimony',
            color: const Color(0xFFFFE76A),
            onTap: _isSubmitting ? null : _submitWitness,
            loading: _isSubmitting,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _panelButton(
            label: 'Cancel',
            color: const Color(0xFFE0E0E0),
            onTap: _isSubmitting
                ? null
                : () => setState(() {
                    _activePanel = null;
                    _error = null;
                  }),
          ),
        ),
      ],
    ),
  );

  Widget get _panelError => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(_error!, style: const TextStyle(color: Colors.red)),
    ),
  );

  Widget _panelButton({
    Key? key,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      key: key,
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF555555),
          disabledBackgroundColor: color.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _PostAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;

  const _PostAvatar({required this.avatarUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final uri = avatarUrl == null ? null : Uri.tryParse(avatarUrl!);
    final validUrl =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF9BC7FA),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: !validUrl
            ? Icon(Icons.person, color: const Color(0xFF347BE5), size: size - 4)
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  color: const Color(0xFF347BE5),
                  size: size - 4,
                ),
              ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final PostsRepository? postsRepository;
  final SocialRepository? socialRepository;
  final YcoinRepository? ycoinRepository;

  const HomePage({
    super.key,
    required this.user,
    this.postsRepository,
    this.socialRepository,
    this.ycoinRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _selectedCategory = 0;
  int _selectedFeedFilter = 0;
  String? _createMode;
  String _postCategory = 'Personal & Family';
  String _postPrivacy = 'public';
  bool _isFeedLoading = false;
  bool _isYcoinLoading = true;
  bool _isCreatingPost = false;
  bool _isSearchingUsers = false;
  bool _isLoadingSocial = false;
  final Set<String> _pendingPostActions = {};
  bool _hasMorePosts = true;
  int _unreadNotificationCount = 0;
  int _socialView = 0;
  String? _nextCursor;
  String? _feedError;
  String? _ycoinBalance;
  String? _ycoinError;
  String? _createPostError;
  String? _notificationError;
  String? _socialError;
  int _feedGeneration = 0;
  int _ycoinRequestGeneration = 0;
  final List<PrayerPost> _posts = [];
  final List<SocialUser> _searchResults = [];
  final List<FriendInvitation> _incomingInvitations = [];
  final List<SocialUser> _friends = [];
  final TextEditingController _postTitle = TextEditingController();
  final TextEditingController _postContent = TextEditingController();
  final TextEditingController _searchUser = TextEditingController();
  final TextEditingController _chatMessage = TextEditingController();

  PostsRepository get _postsRepository =>
      widget.postsRepository ?? PostsService(authService.apiClient.dio);
  SocialRepository get _socialRepository =>
      widget.socialRepository ?? SocialService(authService.apiClient.dio);
  YcoinRepository get _ycoinRepository =>
      widget.ycoinRepository ?? YcoinService(authService.apiClient.dio);

  static const _categories = [
    (label: 'Personal & Family', asset: 'assets/icons/family_and_personal.png'),
    (label: 'Church & Ministry', asset: 'assets/icons/church.png'),
    (label: 'Kingdom Prayer', asset: 'assets/icons/kingdom.png'),
    (label: 'Tribe Prayer', asset: 'assets/icons/tribe.png'),
  ];

  String get _name =>
      (findValue(widget.user, 'displayName') ??
              findValue(widget.user, 'name') ??
              'Prayerlike User')
          .toString();

  String get _email =>
      (findValue(widget.user, 'email') ?? 'No email').toString();

  String get _handle =>
      (findValue(widget.user, 'handle') ??
              findValue(widget.user, 'userId') ??
              _name)
          .toString();

  String get _tribe {
    final value =
        findValue(widget.user, 'tribeCode') ??
        findValue(widget.user, 'tribe') ??
        'Judah';
    if (value is Map) {
      return (value['name'] ?? value['code'] ?? 'Judah').toString();
    }
    return value.toString();
  }

  String? get _avatarUrl {
    final value =
        findValue(widget.user, 'avatarUrl') ??
        findValue(widget.user, 'photoUrl') ??
        findValue(widget.user, 'picture') ??
        findValue(widget.user, 'avatar');
    if (value is! String || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return value;
  }

  @override
  void initState() {
    super.initState();
    _loadFeed(reset: true);
    _loadYcoinBalance();
    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    _postTitle.dispose();
    _postContent.dispose();
    _searchUser.dispose();
    _chatMessage.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool reset = false}) async {
    if ((!reset && _isFeedLoading) || (!reset && !_hasMorePosts)) return;
    if (!reset && (_nextCursor == null || _nextCursor!.isEmpty)) return;

    final generation = reset ? ++_feedGeneration : _feedGeneration;
    final category = _categories[_selectedCategory].label;
    final cursor = reset ? null : _nextCursor;
    setState(() {
      _isFeedLoading = true;
      _feedError = null;
      if (reset) {
        _posts.clear();
        _nextCursor = null;
        _hasMorePosts = true;
      }
    });

    try {
      final page = await _postsRepository.getFeed(
        category: category,
        cursor: cursor,
        pageSize: 10,
      );
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        final existingIds = _posts.map((post) => post.postId).toSet();
        _posts.addAll(page.items.where((post) => existingIds.add(post.postId)));
        _nextCursor = page.nextCursor;
        _hasMorePosts = page.nextCursor != null;
        _isFeedLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _isFeedLoading = false;
        _feedError = cleanError(error);
      });
    }
  }

  Future<void> _loadYcoinBalance() async {
    final requestGeneration = ++_ycoinRequestGeneration;
    if (_ycoinBalance == null) {
      setState(() {
        _isYcoinLoading = true;
        _ycoinError = null;
      });
    }

    try {
      final balance = await _ycoinRepository.getBalance();
      if (!mounted || requestGeneration != _ycoinRequestGeneration) return;
      setState(() {
        _ycoinBalance = balance;
        _isYcoinLoading = false;
        _ycoinError = null;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _ycoinRequestGeneration) return;
      setState(() {
        _ycoinError = cleanError(error);
        _isYcoinLoading = false;
      });
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _socialRepository.getUnreadNotificationCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (error) {
      if (mounted) {
        setState(() => _notificationError = cleanError(error));
      }
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchUser.text.trim();
    if (query.isEmpty) {
      setState(() => _socialError = 'Enter a user ID or name.');
      return;
    }
    setState(() {
      _isSearchingUsers = true;
      _socialError = null;
      _searchResults.clear();
    });
    try {
      final results = await _socialRepository.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results);
        _isSearchingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _socialError = cleanError(error);
        _isSearchingUsers = false;
      });
    }
  }

  Future<void> _loadSocialLists() async {
    setState(() {
      _isLoadingSocial = true;
      _socialError = null;
    });
    try {
      final results = await Future.wait([
        _socialRepository.getIncomingInvitations(),
        _socialRepository.getFriends(),
      ]);
      if (!mounted) return;
      setState(() {
        _incomingInvitations
          ..clear()
          ..addAll(results[0] as List<FriendInvitation>);
        _friends
          ..clear()
          ..addAll(results[1] as List<SocialUser>);
        _isLoadingSocial = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _socialError = cleanError(error);
        _isLoadingSocial = false;
      });
    }
  }

  Future<void> _sendInvitation(SocialUser user) async {
    try {
      await _socialRepository.sendFriendInvitation(user.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${user.displayName}.')),
      );
      await _loadSocialLists();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanError(error))));
      }
    }
  }

  Future<void> _respondToInvitation(
    FriendInvitation invitation, {
    required bool accept,
  }) async {
    try {
      await _socialRepository.respondToInvitation(
        invitation.invitationId,
        accept: accept,
      );
      await _loadSocialLists();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanError(error))));
      }
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(repository: _socialRepository),
      ),
    );
    if (mounted) {
      await _loadUnreadNotificationCount();
    }
  }

  Future<void> _amenPost(PrayerPost post) async {
    if (!_pendingPostActions.add(post.postId)) return;
    setState(() {});
    try {
      final engagement = await _postsRepository.amenPost(post.postId);
      if (!mounted) return;
      _replacePost(
        post.copyWith(
          amenCount: engagement.amenCount,
          amened: engagement.amened,
        ),
      );
      _loadYcoinBalance();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanError(error))));
      }
    } finally {
      _pendingPostActions.remove(post.postId);
      if (mounted) setState(() {});
    }
  }

  void _replacePost(PrayerPost updatedPost) {
    final index = _posts.indexWhere(
      (post) => post.postId == updatedPost.postId,
    );
    if (index < 0) return;
    setState(() => _posts[index] = updatedPost);
  }

  Future<void> _sendPostComment(PrayerPost post, String content) async {
    await _postsRepository.createComment(post.postId, content);
    if (!mounted) return;
    _replacePost(post.copyWith(commentCount: post.commentCount + 1));
    _loadYcoinBalance();
  }

  Future<void> _sendPostWitness(PrayerPost post, String content) async {
    await _postsRepository.createWitness(post.postId, content);
    if (!mounted) return;
    _replacePost(post.copyWith(witnessed: true));
    _loadYcoinBalance();
  }

  Future<void> _sharePost(PrayerPost post) async {
    final text = [
      if (post.title != null && post.title!.isNotEmpty) post.title!,
      post.content,
    ].join('\n\n');
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      _loadYcoinBalance();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanError(error))));
      }
    }
  }

  void _openYcoinHistory() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => YcoinHistoryPage(
          repository: _ycoinRepository,
          balance: _ycoinBalance,
          onNavigate: (index) => setState(() => _selectedIndex = index),
        ),
      ),
    ).then((_) {
      if (mounted) _loadYcoinBalance();
    });
  }

  Future<void> _publishPost() async {
    final content = _postContent.text.trim();
    final title = _postTitle.text.trim();
    if (content.isEmpty || content.length > 500) {
      setState(() {
        _createPostError = 'Content must be between 1 and 500 characters.';
      });
      return;
    }
    if (title.length > 100) {
      setState(
        () => _createPostError = 'Title must be 100 characters or fewer.',
      );
      return;
    }
    if (_isCreatingPost) return;

    setState(() {
      _isCreatingPost = true;
      _createPostError = null;
    });
    try {
      await _postsRepository.createPost(
        content: content,
        title: title.isEmpty ? null : title,
        category: _postCategory,
        privacy: _postPrivacy,
      );
      if (!mounted) return;

      _postTitle.clear();
      _postContent.clear();
      setState(() {
        _isCreatingPost = false;
        _createMode = null;
        _selectedIndex = 0;
        _selectedCategory = _categories.indexWhere(
          (category) => category.label == _postCategory,
        );
      });
      await _loadFeed(reset: true);
      _loadYcoinBalance();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post published.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCreatingPost = false;
        _createPostError = cleanError(error);
      });
    }
  }

  Future<void> _editPost(PrayerPost post) async {
    // 顯示編輯貼文的對話框或導航到編輯頁面
    // 這裡可以實現編輯功能，例如導航到編輯頁面或顯示對話框
    // 目前先顯示提示訊息
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editing post: ${post.postId}')),
    );
    _loadYcoinBalance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: appBackground,
      body: SafeArea(child: _buildSelectedPage()),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeFeedPage();
      case 1:
        return _buildPrayerFeedPage();
      case 2:
        return _buildCreatePage();
      case 3:
        return _buildSearchPage();
      case 4:
        return _buildNovaPage();
      default:
        return _buildHomeFeedPage();
    }
  }

  Widget _buildPrayerFeedPage() => _buildFeedPage(isPrayerPage: true);

  Widget _buildHomeFeedPage() => _buildFeedPage(isPrayerPage: false);

  Widget _buildFeedPage({required bool isPrayerPage}) {
    return Column(
      children: [
        _buildFeedHeader(),
        _buildCategoryBar(),
        _buildFeedFilters(isPrayerPage: isPrayerPage),
        Expanded(child: _buildEmptyFeed()),
      ],
    );
  }

  Widget _buildFeedHeader() {
    final tribeImage = 'assets/images/tribes/${_tribe.toLowerCase()}.png';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              GestureDetector(
                key: const ValueKey('profile-avatar'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfilePage(
                      name: _name,
                      handle: _handle,
                      email: _email,
                      tribe: _tribe,
                      avatarUrl: _avatarUrl,
                    ),
                  ),
                ),
                child: _buildAvatar(size: 44),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 105),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: cream,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('notifications-button'),
                tooltip: _notificationError ?? 'Notifications',
                onPressed: _openNotifications,
                icon: Badge(
                  isLabelVisible: _unreadNotificationCount > 0,
                  label: Text(
                    _unreadNotificationCount > 99
                        ? '99+'
                        : '$_unreadNotificationCount',
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                key: const ValueKey('ycoin-balance'),
                onTap: _openYcoinHistory,
                child: Tooltip(
                  message: _ycoinError ?? 'Ycoin balance',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xFFFFD000),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 68,
                          child: Text(
                            _ycoinBalance ?? (_isYcoinLoading ? '…' : '!'),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Row(
            children: [
              Image.asset(
                tribeImage,
                width: 40,
                height: 40,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.groups, color: cream, size: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tribe.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _headerAction(
                icon: Icons.groups,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _confirmLogout(context),
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: const BoxDecoration(
                    color: cream,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: appIconBrown, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFD1D1D1)),
      ],
    );
  }

  Widget _buildAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF9BC7FA),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: _avatarUrl == null
            ? Icon(
                Icons.person,
                color: const Color(0xFF347BE5),
                size: size * 0.9,
              )
            : Image.network(
                _avatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  color: const Color(0xFF347BE5),
                  size: size * 0.9,
                ),
              ),
      ),
    );
  }

  Widget _headerAction({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: const BoxDecoration(color: cream, shape: BoxShape.circle),
        child: Icon(icon, color: appIconBrown, size: 25),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final category = _categories[index];
          final selected = index == _selectedCategory;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedCategory == index) return;
                setState(() => _selectedCategory = index);
                _loadFeed(reset: true);
              },
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: selected ? appSelected : cream,
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: appIconBrown, width: 2)
                          : null,
                    ),
                    child: Image.asset(category.asset),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 94),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? appSelected : const Color(0xFFFFE7B3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appIconBrown, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeedFilters({required bool isPrayerPage}) {
    final filters = isPrayerPage
        ? const ['Original Post', 'Witness Wall', 'Activity']
        : const ['Original Post', 'Witness Wall'];

    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFD1D1D1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: List.generate(filters.length, (index) {
              final selected = index == _selectedFeedFilter;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFeedFilter = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? appSelected : cream,
                        border: Border.all(
                          color: const Color(0xFFFFD000),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        filters[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeed() {
    if (_posts.isEmpty && _isFeedLoading) {
      return const Center(child: CircularProgressIndicator(color: appSelected));
    }

    if (_posts.isEmpty && _feedError != null) {
      return _feedMessage(
        icon: Icons.cloud_off,
        message: _feedError!,
        actionLabel: 'Retry',
        onAction: () => _loadFeed(reset: true),
      );
    }

    if (_posts.isEmpty) {
      return _feedMessage(
        icon: Icons.mail_outline,
        message: 'No posts matching this filter',
        detail:
            'Current category: ${_categories[_selectedCategory].label} - No data available',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 280 &&
            !_isFeedLoading &&
            _hasMorePosts) {
          _loadFeed();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 12),
        itemCount:
            _posts.length + (_isFeedLoading || _feedError != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            if (_feedError != null) {
              return TextButton(
                onPressed: _loadFeed,
                child: Text('Could not load more posts: $_feedError · Retry'),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: appSelected),
              ),
            );
          }
          return _buildPostCard(_posts[index]);
        },
        // 添加滾動監聽器以實現無限滾動
        controller: ScrollController(),
        physics: const AlwaysScrollableScrollPhysics(),
      ),
    );
  }

  Widget _feedMessage({
    required IconData icon,
    required String message,
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 8, 9, 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: appSelected, size: 60),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB9C1D5), fontSize: 15),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _buildPostCard(PrayerPost post) {
    final author = post.author;
    final authorName = author?.displayName ?? 'Unknown user';
    final avatar = author?.avatarUrl;
    final isPostAuthor =
        findValue(widget.user, 'userId')?.toString() == post.userId;
    final date =
        '${post.createdAt.toLocal().year.toString().padLeft(4, '0')}-'
        '${post.createdAt.toLocal().month.toString().padLeft(2, '0')}-'
        '${post.createdAt.toLocal().day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostAvatar(avatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: const TextStyle(color: gray, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (post.category != null)
                _postTag(post.category!, category: true),
              const SizedBox(width: 5),
              _postTag(_privacyLabel(post.privacy)),
              if (isPostAuthor)
                IconButton(
                  key: ValueKey('edit-post-${post.postId}'),
                  tooltip: 'Edit post',
                  onPressed: () => _editPost(post),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: appIconBrown,
                  ),
                )
              else
                IconButton(
                  key: ValueKey('share-post-${post.postId}'),
                  tooltip: 'Share post',
                  onPressed: () => _sharePost(post),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 19,
                    color: appIconBrown,
                  ),
                ),
            ],
          ),
          if (post.title != null && post.title!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              post.title!,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            post.content,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 16,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _PostInteractionPanel(
            key: ValueKey('post-interactions-${post.postId}'),
            post: post,
            isPostAuthor:
                findValue(widget.user, 'userId')?.toString() == post.userId,
            onAmen: _pendingPostActions.contains(post.postId)
                ? null
                : () => _amenPost(post),
            onLoadComments: (cursor) =>
                _postsRepository.getComments(post.postId, cursor: cursor),
            onLoadWitnesses: () => _postsRepository.getWitnesses(post.postId),
            onAmenComment: (commentId) async {
              final engagement = await _postsRepository.amenComment(commentId);
              _loadYcoinBalance();
              return engagement;
            },
            onSendComment: (content) => _sendPostComment(post, content),
            onSendWitness: (content) => _sendPostWitness(post, content),
            onYcoinUpdate: _loadYcoinBalance,
          ),
        ],
      ),
    );
  }

  Widget _buildPostAvatar(String? avatarUrl) {
    final uri = avatarUrl == null ? null : Uri.tryParse(avatarUrl);
    final validUrl =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF9BC7FA),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: !validUrl
            ? const Icon(Icons.person, color: Color(0xFF347BE5), size: 36)
            : Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.person,
                  color: Color(0xFF347BE5),
                  size: 36,
                ),
              ),
      ),
    );
  }

  Widget _postTag(String label, {bool category = false}) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: category ? const Color(0xFFFFFBE3) : const Color(0xFFFFFBE3),
          border: Border.all(color: const Color(0xFFFFE76A)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category ? label : _privacyLabel(label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE0C300), fontSize: 10),
        ),
      ),
    );
  }

  String _privacyLabel(String privacy) {
    switch (privacy) {
      case 'public':
        return 'PUBLIC';
      case 'family':
        return 'FAMILY';
      case 'tribe':
        return 'TRIBE';
      case 'individual':
        return 'INDIVIDUAL';
      default:
        return privacy.toUpperCase();
    }
  }

  Widget _buildCreatePage() {
    if (_createMode == 'text') return _buildTextPostPage();
    if (_createMode == 'voice') return _buildVoicePostPage();

    return Column(
      children: [
        _backButton(() => setState(() => _selectedIndex = 0)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _createChoice(
                    'Create text post',
                    () => setState(() => _createMode = 'text'),
                  ),
                  const SizedBox(height: 54),
                  _createChoice(
                    'Create voice post',
                    () => setState(() => _createMode = 'voice'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backButton(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _createChoice(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: cream,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(title, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildTextPostPage() {
    return Column(
      children: [
        _backButton(() => setState(() => _createMode = null)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(17, 26, 17, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    _postDropdown(
                      value: _postPrivacy,
                      options: const {
                        'public': 'Public',
                        'family': 'Family',
                        'tribe': 'Tribe',
                        'individual': 'Individual',
                      },
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postPrivacy = value);
                        }
                      },
                    ),
                    const SizedBox(width: 14),
                    _postDropdown(
                      value: _postCategory,
                      options: {
                        for (final category in _categories)
                          category.label: category.label,
                      },
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _postCategory = value);
                        }
                      },
                    ),
                  ],
                ),
                if (_createPostError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _createPostError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('post-title'),
                        controller: _postTitle,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: 'Title',
                          filled: true,
                          fillColor: Color(0xFFD8D8D8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        key: const ValueKey('post-content'),
                        controller: _postContent,
                        maxLength: 500,
                        maxLines: 9,
                        decoration: const InputDecoration(
                          hintText: 'Write your prayer here... (Max 500 words)',
                          filled: true,
                          fillColor: Color(0xFFD8D8D8),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('publish-post'),
                        onPressed: _isCreatingPost ? null : _publishPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appSelected,
                          foregroundColor: appBackground,
                        ),
                        child: _isCreatingPost
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('post'),
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: TextButton(
                        onPressed: _isCreatingPost
                            ? null
                            : () => setState(() => _createMode = null),
                        child: const Text(
                          'cancel',
                          style: TextStyle(color: Color(0xFF8994AD)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _postDropdown({
    required String value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
            items: options.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildVoicePostPage() {
    return Column(
      children: [
        _backButton(() => setState(() => _createMode = null)),
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: cream,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Voice Post',
                      style: TextStyle(
                        color: navy,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text('🎤', style: TextStyle(fontSize: 62)),
                  const SizedBox(height: 18),
                  const Text(
                    'Ready to Record',
                    style: TextStyle(
                      color: navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click "Start Recording" to begin speaking',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gray, fontSize: 17),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appSelected,
                            foregroundColor: navy,
                          ),
                          child: const Text('Start Recording'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _createMode = null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: navy,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(() => setState(() => _selectedIndex = 0)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Search')),
              ButtonSegment(value: 1, label: Text('Requests')),
              ButtonSegment(value: 2, label: Text('Friends')),
            ],
            selected: {_socialView},
            onSelectionChanged: (selection) {
              setState(() => _socialView = selection.first);
              if (_socialView != 0) _loadSocialLists();
            },
          ),
        ),
        if (_socialView == 0) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchUser,
                    style: const TextStyle(color: appBackground),
                    decoration: InputDecoration(
                      hintText: 'Search by User ID (e.g., yaa, john123)',
                      hintStyle: const TextStyle(color: Color(0xFF9A9A9A)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    key: const ValueKey('search-users'),
                    onPressed: _isSearchingUsers ? null : _searchUsers,
                    icon: _isSearchingUsers
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, color: appIconBrown),
                  ),
                ),
              ],
            ),
          ),
          if (_socialError != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _socialError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _searchResults.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        'Search by user ID or name, then send a friend request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9BAAC9),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    children: _searchResults
                        .map(
                          (user) => ListTile(
                            leading: _buildPostAvatar(user.avatarUrl),
                            title: Text(
                              user.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              user.handle == null
                                  ? user.userId
                                  : '@${user.handle}',
                              style: const TextStyle(color: Color(0xFFB9C1D5)),
                            ),
                            trailing: user.relation == 'friend'
                                ? const Text('Friends')
                                : IconButton(
                                    key: ValueKey('invite-${user.userId}'),
                                    tooltip: 'Add friend',
                                    onPressed: () => _sendInvitation(user),
                                    icon: const Icon(
                                      Icons.person_add_alt_1,
                                      color: appSelected,
                                    ),
                                  ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ] else if (_isLoadingSocial)
          const Expanded(
            child: Center(child: CircularProgressIndicator(color: appSelected)),
          )
        else if (_socialError != null)
          Expanded(
            child: Center(
              child: Text(
                _socialError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else if (_socialView == 1)
          Expanded(
            child: _incomingInvitations.isEmpty
                ? const Center(
                    child: Text(
                      'No pending friend requests.',
                      style: TextStyle(color: Color(0xFFB9C1D5)),
                    ),
                  )
                : ListView(
                    children: _incomingInvitations
                        .map(
                          (invitation) => ListTile(
                            leading: _buildPostAvatar(invitation.avatarUrl),
                            title: Text(
                              invitation.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: 'Accept invitation',
                                  onPressed: () => _respondToInvitation(
                                    invitation,
                                    accept: true,
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Decline invitation',
                                  onPressed: () => _respondToInvitation(
                                    invitation,
                                    accept: false,
                                  ),
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          )
        else
          Expanded(
            child: _friends.isEmpty
                ? const Center(
                    child: Text(
                      'No friends yet.',
                      style: TextStyle(color: Color(0xFFB9C1D5)),
                    ),
                  )
                : ListView(
                    children: _friends
                        .map(
                          (friend) => ListTile(
                            leading: _buildPostAvatar(friend.avatarUrl),
                            title: Text(
                              friend.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              friend.handle == null
                                  ? friend.userId
                                  : '@${friend.handle}',
                              style: const TextStyle(color: Color(0xFFB9C1D5)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
      ],
    );
  }

  Widget _buildNovaPage() {
    return Column(
      children: [
        Container(
          height: 64,
          color: const Color(0xFF15233E),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.white, size: 27),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nova AI Assistant',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '● Online  ·  10 questions remaining',
                      style: TextStyle(color: Color(0xFF00B98E), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: appDarkSurface,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/icons/Nova_com.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B394A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Hello! I am Nova, your AI assistant. How can I help you today?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 5, top: 8),
                        child: Text(
                          '11:39 AM',
                          style: TextStyle(
                            color: Color(0xFF9BAAC9),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Color(0xFF15233E),
            border: Border(top: BorderSide(color: Color(0xFF384564))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatMessage,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ask Nova anything...',
                    hintStyle: const TextStyle(color: Color(0xFF9BAAC9)),
                    filled: true,
                    fillColor: appDarkSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF34415D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.send, color: Color(0xFF34415D), size: 27),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cream,
        title: const Text(
          'Log Out?',
          style: TextStyle(color: navy, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: creamButton(),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // 清除本機 Cookie
      await authService.logout();

      if (!context.mounted) return;

      // 清除所有先前頁面，避免返回首頁
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged out locally, but server logout failed: ${cleanError(e)}',
          ),
        ),
      );
    }
  }
}
