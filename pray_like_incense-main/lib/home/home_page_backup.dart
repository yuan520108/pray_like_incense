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
import '../pages/notification_page.dart'; // 修改?�正確�?路�?

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

  Future<void> _loadPosts([bool refresh = false]) async {
    if (refresh) {
      _currentPage = 1;
      _posts.clear();
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 使用postsRepository加载真实的贴文数据
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
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load posts: $error';
      });
    }
  }
  }

  Future<void> _loadYCoinBalance() async {
    try {
      final userId = widget.user['userId']?.toString() ?? 'unknown_user';
      final balance = await widget.yCoinService.getYCoinBalance(userId);
      setState(() {
        _yCoinBalance = balance;
      });
    } catch (error) {
      print('Failed to load Y coin balance: $error');
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMorePosts || _isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _currentPage++;
      await _loadPosts(false);
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load more posts: $error';
      });
    }
  }

  // Future<void> _publishPost(String content, [String? title]) async {
  //   try {
  //     // ?�裡?�該調用API?��?貼�?
  //     // final newPost = await _postsService.createPost(title, content);
  //     // _posts.insert(0, newPost);
  //     
  //     // 模擬?��??��?
  //     await Future.delayed(const Duration(seconds: 1));
  //     
  //     // ?�新Y�?
  //     await widget.yCoinService.handlePostInteraction(
  //       widget.user['userId']?.toString() ?? 'unknown_user', 
  //       'create_post'
  //     );
  //     
  //     // ?�新?��?貼�?
  //     await _loadPosts();
  //     await _loadYCoinBalance();
  //     
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Post published successfully!'))
  //       );
  //     }
  //   } catch (error) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to publish post: $error'))
  //       );
  //     }
  //   }
  // }

  Future<void> _handleAmen(String postId) async {
    try {
      // 模擬?��?
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ?�新Y�?
      await widget.yCoinService.handlePostInteraction(
        widget.user['userId']?.toString() ?? 'unknown_user', 
        'amen'
      );
      
      // ?�新?��?貼�?
      await _loadPosts();
      await _loadYCoinBalance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amen added!'))
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add amen: $error'))
        );
      }
    }
  }

  Future<void> _handleComment(String postId) async {
    try {
      // 模擬評�?
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ?�新Y�?
      await widget.yCoinService.handlePostInteraction(
        widget.user['userId']?.toString() ?? 'unknown_user', 
        'comment'
      );
      
      // ?�新?��?貼�?
      await _loadPosts();
      await _loadYCoinBalance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added!'))
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $error'))
        );
      }
    }
  }

  Future<void> _handleWitness(String postId, String content) async {
    try {
      // 模擬Witness
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ?�新Y�?
      await widget.yCoinService.handlePostInteraction(
        widget.user['userId']?.toString() ?? 'unknown_user', 
        'witness'
      );
      
      // ?�新?��?貼�?
      await _loadPosts();
      await _loadYCoinBalance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Witness posted!'))
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post witness: $error'))
        );
      }
    }
  }

  Future<void> _handleEditPost(String postId, String title, String content) async {
    try {
      // 模擬編輯貼�?
      await Future.delayed(const Duration(milliseconds: 500));
      
      // ?�新Y�?
      await widget.yCoinService.handlePostInteraction(
        widget.user['userId']?.toString() ?? 'unknown_user', 
        'edit_post'
      );
      
      // ?�新?��?貼�?
      await _loadPosts();
      await _loadYCoinBalance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post edited successfully!'))
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit post: $error'))
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pray Like Incense'),
        actions: [
          // ?�知?��?
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        // 跳�??�通知?�面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NotificationPage(
                              notificationCount: 5,
                              onNotificationTap: () {
                                // ?��??�知點�?
                              },
                            ),
                          ),
                        );
                      },
                    ),
          // Y�?���?
          YCoinDisplay(
            balance: _yCoinBalance, 
            onTap: () {
              // 點�?Y�?��示跳轉到Y�?��?��?
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      TextButton(
                        onPressed: _loadPosts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final isPostAuthor = (widget.user['userId']?.toString() ?? 'unknown_user') == post.userId;
                    
                    return PostCard(
                      post: post,
                      isPostAuthor: isPostAuthor,
                      onEdit: () {
                        // 編輯貼�??�能
                        _showEditPostDialog(post);
                      },
                      onDelete: () {
                                            // 刪除貼文功能
                                            // 在这里添加删除贴文的逻辑
                                          },
                                          onLike: () => _handleAmen(post.postId),
                                          onComment: () => _handleComment(post.postId),
                                          onWitness: () => _showWitnessDialog(post.postId),
                                          onRefresh: () {
                                            // 刷新功能
                                          },
                                        );
                  },
                ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  void _showEditPostDialog(PrayerPost post) {
    final titleController = TextEditingController(text: post.title);
    final contentController = TextEditingController(text: post.content);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                ),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleEditPost(post.postId, titleController.text, contentController.text);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showWitnessDialog(String postId) {
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Witness Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Witness Content',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              const Text('You can add photo later'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleWitness(postId, contentController.text);
              },
              child: const Text('Post Witness'),
            ),
          ],
        );
      },
    );
  }
}
