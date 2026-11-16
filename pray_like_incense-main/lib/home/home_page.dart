import 'package:flutter/material.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/post_card.dart';
import '../widgets/ycoin_display.dart';
import '../widgets/notification_badge.dart';
import '../models/prayer_post.dart';
import '../services/ycoin_service.dart';
import '../services/witness_service.dart';
import '../services/posts_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../pages/notification_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiClient apiClient;
  final AuthService authService;
  final YCoinService yCoinService;
  final WitnessService witnessService;
  final PostsRepository? postsRepository;

  const HomePage({
    super.key,
    required this.user,
    required this.apiClient,
    required this.authService,
    required this.yCoinService,
    required this.witnessService,
    this.postsRepository,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _selectedCategory = 0;
  int _selectedFeedFilter = 0;
  String? _createMode;
  List<PrayerPost> _posts = [];
  bool _isLoading = false;
  int _yCoinBalance = 0;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePosts = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadYCoinBalance();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMorePosts();
      }
    });
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 检查postsRepository是否存在
      if (widget.postsRepository == null) {
        throw Exception('postsRepository is null');
      }
      
      // 获取帖子数据
      final response = await widget.postsRepository!.getPosts(
        page: _currentPage,
        limit: 25,
      );
      
      final postsData = response['data']['items'] as List?;
      
      if (postsData != null) {
        final newPosts = postsData.map((data) {
          return PrayerPost.fromJson(data);
        }).toList();
        
        if (refresh) {
          setState(() {
            _posts = newPosts;
          });
        } else {
          setState(() {
            _posts.addAll(newPosts);
          });
        }
      }
      
      // 更新是否有更多帖子的状态
      setState(() {
        _hasMorePosts = postsData != null && postsData.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '載入貼文失敗: $e';
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _isLoading) return;
    _loadPosts();
  }

  Future<void> _loadYCoinBalance() async {
    try {
      final balance = await widget.yCoinService.getYCoinBalance();
      setState(() {
        _yCoinBalance = balance;
      });
    } catch (e) {
      print('Failed to load YCoin balance: $e');
    }
  }

  void _onLogout() {
    // 显示登出确认对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('登出確認'),
          content: const Text('確定要登出帳號嗎？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 执行登出逻辑
                // widget.authService.logout();
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
      },
    );
  }

  void _onCreatePost() {
    setState(() {
      _createMode = 'post';
    });
  }

  void _onCancelCreate() {
    setState(() {
      _createMode = null;
    });
  }

  void _onCreatePhotoPost() {
    // 实现创建照片贴文逻辑
    print('Creating photo post...');
    setState(() {
      _createMode = null;
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedCategory = index;
    });
  }

  void _onFeedFilterSelected(int index) {
    setState(() {
      _selectedFeedFilter = index;
    });
  }

  void _onPostLiked(String postId) {
    // 实现点赞功能
    print('Post liked: $postId');
    // 这里应该调用API更新点赞数并更新Y币
    setState(() {
      _yCoinBalance += 1; // 点赞增加1个Y币
    });
  }

  void _onPostCommented(String postId) {
    // 实现评论功能
    print('Post commented: $postId');
    // 这里应该调用API更新评论数并更新Y币
    setState(() {
      _yCoinBalance += 1; // 评论增加1个Y币
    });
  }

  void _onWitnessPosted(String postId) {
    // 实现见证功能
    print('Witness posted for post: $postId');
    // 这里应该显示见证输入框
  }

  void _onEditPost(PrayerPost post) {
    // 实现编辑功能
    print('Editing post: ${post.postId}');
    // 这里应该弹出编辑对话框或导航到编辑页面
  }

  void _onPostDeleted(String postId) {
    // 实现删除功能
    print('Post deleted: $postId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF262E52),
        title: const Text(
          'Pray Like Incense',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 返回上一页的逻辑
            Navigator.pop(context);
          },
        ),
        actions: [
          // 通知图标
          IconButton(
            icon: const NotificationBadge(
              badgeCount: 3,
              icon: Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationPage(),
                ),
              );
            },
          ),
          // Y币显示
          YCoinDisplay(
            balance: _yCoinBalance,
            onTap: () {
              // 点击Y币显示详细记录
              // 可以导航到Y币记录页面
            },
          ),
          // 登出按钮
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _onLogout,
          ),
        ],
      ),
      body: _createMode != null
          ? _buildCreatePostScreen()
          : RefreshIndicator(
              onRefresh: () async {
                _currentPage = 1;
                _posts.clear();
                _loadPosts(refresh: true);
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Container(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _errorMessage ?? '沒有更多貼文了',
                              textAlign: TextAlign.center,
                            ),
                          );
                  }
                  return _buildPostCard(_posts[index]);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreatePost,
        backgroundColor: const Color(0xFFF9D464),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _onTabSelected,
      ),
    );
  }

  Widget _buildCreatePostScreen() {
    return Column(
      children: [
        // 创建贴文顶部栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _onCancelCreate,
                child: const Text('取消'),
              ),
              const Text('发布贴文'),
              TextButton(
                onPressed: _onCreatePhotoPost,
                child: const Text('发送'),
              ),
            ],
          ),
        ),
        // 创建贴文内容区域
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '标题',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: '内容',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // 发布贴文逻辑
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('发布'),
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

  Widget _buildPostCard(PrayerPost post) {
    final isPostAuthor = (widget.user['userId']?.toString() ?? 'unknown_user') == post.userId;
    
    return PostCard(
      post: post,
      isPostAuthor: isPostAuthor,
      onLike: () => _onPostLiked(post.postId),
      onComment: () => _onPostCommented(post.postId),
      onWitness: () => _onWitnessPosted(post.postId),
      onEdit: () => _onEditPost(post),
      onDelete: () => _onPostDeleted(post.postId),
    );
  }
}