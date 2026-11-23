import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/friends_service.dart';

class FriendSearchPage extends StatefulWidget {
  final FriendsService friendsService;

  const FriendSearchPage({super.key, required this.friendsService});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final List<FriendSearchResult> _results = [];
  final Set<String> _sendingInvitations = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results.clear();
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }
    if (query.length > 120 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });
    try {
      final results = await widget.friendsService.searchUsers(query: query);
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _sendInvitation(int index) async {
    final user = _results[index];
    if (_sendingInvitations.contains(user.userId)) return;
    setState(() => _sendingInvitations.add(user.userId));
    try {
      final result = await widget.friendsService.sendInvitation(
        targetUserId: user.userId,
      );
      if (!mounted) return;
      final resultIndex = _results.indexWhere(
        (item) => item.userId == user.userId,
      );
      setState(() {
        if (resultIndex >= 0) {
          _results[resultIndex] = user.copyWith(
            relation: result.alreadyFriends || result.autoAccepted
                ? 'friend'
                : 'pending_outgoing',
          );
        }
        _sendingInvitations.remove(user.userId);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendingInvitations.remove(user.userId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: appBackground,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  maxLength: 120,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Search by User ID (e.g., yaa, john123)',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: appCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(36),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: appCard,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _isLoading ? null : _search,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 28),
                  iconSize: 44,
                  color: appIconBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: appGold));
    }
    if (!_hasSearched) {
      return const Center(
        child: Text(
          '🔍  Search for friends by User ID to start connecting!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFA8BFE7), fontSize: 16),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Color(0xFFA8BFE7), fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _results[index];
        final isSending = _sendingInvitations.contains(user.userId);
        return Container(
          decoration: appCardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF9DC8FF),
                backgroundImage: user.avatarUrl == null
                    ? null
                    : NetworkImage(_resolveMediaUrl(user.avatarUrl!)),
                child: user.avatarUrl == null
                    ? const Icon(Icons.person, color: Color(0xFF2874D0))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.handle != null)
                      Text(
                        '@${user.handle}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
              _buildRelationButton(user, isSending, index),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRelationButton(
    FriendSearchResult user,
    bool isSending,
    int index,
  ) {
    if (user.relation == 'friend') {
      return const Text('Friends', style: TextStyle(color: appIconBrown));
    }
    if (user.relation == 'pending_outgoing') {
      return const Text('Request sent', style: TextStyle(color: appIconBrown));
    }
    if (user.relation == 'pending_incoming') {
      return const Text(
        'Request received',
        style: TextStyle(color: appIconBrown),
      );
    }
    return ElevatedButton(
      onPressed: isSending ? null : () => _sendInvitation(index),
      style: ElevatedButton.styleFrom(
        backgroundColor: appGold,
        foregroundColor: Colors.black,
      ),
      child: isSending
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Add friend'),
    );
  }

  String _resolveMediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return Uri.parse(ApiClient.baseUrl).resolve(value).toString();
  }
}
