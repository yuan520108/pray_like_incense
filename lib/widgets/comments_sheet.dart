import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/app_theme.dart';
import '../services/posts_service.dart';

class CommentsPanel extends StatefulWidget {
  final PostsRepository postsRepository;
  final String postId;
  final int initialCommentCount;
  final Future<void> Function() onCommentAdded;
  final VoidCallback onClose;

  const CommentsPanel({
    super.key,
    required this.postsRepository,
    required this.postId,
    required this.initialCommentCount,
    required this.onCommentAdded,
    required this.onClose,
  });

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<CommentsPanel> {
  final List<PostComment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String? _nextCursor;
  String? _errorMessage;
  int _commentCount = 0;
  bool _isLoading = false;
  bool _isSending = false;
  bool _isListening = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.initialCommentCount;
    _loadComments();
  }

  Future<void> _loadComments() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await widget.postsRepository.getComments(
        postId: widget.postId,
        cursor: _nextCursor,
        pageSize: 25,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null && page.nextCursor!.isNotEmpty;
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

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      final comment = await widget.postsRepository.createComment(
        postId: widget.postId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _commentCount++;
        _commentController.clear();
        _isSending = false;
      });
      await widget.onCommentAdded();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleCommentAmen(int index) async {
    final comment = _comments[index];
    try {
      final result = await widget.postsRepository.toggleAmen(
        targetId: comment.commentId,
        targetType: 'comment',
      );
      if (!mounted) return;
      setState(() {
        _comments[index] = PostComment(
          commentId: comment.commentId,
          postId: comment.postId,
          userId: comment.userId,
          content: comment.content,
          createdAt: comment.createdAt,
          author: comment.author,
          amenCount: result.amenCount,
          amened: result.amened,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleSpeechInput() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => _isListening = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Speech recognition failed: ${error.errorMsg}'),
              ),
            );
          }
        },
      );
      if (!available) {
        throw StateError('Speech recognition is not available on this device.');
      }
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 60),
        ),
        onResult: (result) {
          if (!mounted) return;
          _commentController.value = TextEditingValue(
            text: result.recognizedWords,
            selection: TextSelection.collapsed(
              offset: result.recognizedWords.length,
            ),
          );
        },
      );
      if (mounted) setState(() => _isListening = _speech.isListening);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isListening = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8FF),
        border: Border.all(color: appCommentBlue, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _commentController,
            maxLength: 2000,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Write your comment...',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: appIconBrown,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: _isListening ? 'Stop dictation' : 'Dictate',
                    onPressed: _toggleSpeechInput,
                    color: Colors.white,
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D9BEA),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pray For You'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appGray,
                    foregroundColor: Colors.black54,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '💬 Prayers ($_commentCount)',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          if (_comments.isEmpty && !_isLoading && _errorMessage == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'No comments yet. Be the first to leave a message!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            ),
          for (var index = 0; index < _comments.length; index++)
            _buildComment(_comments[index], index),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(_errorMessage!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loadComments,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_hasMore && !_isLoading && _errorMessage == null)
            TextButton(
              onPressed: _loadComments,
              child: const Text('Load more prayers'),
            ),
        ],
      ),
    );
  }

  Widget _buildComment(PostComment comment, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF7662C7),
                child: Text(
                  (comment.author?.displayName ?? 'U').characters.first,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author?.displayName ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDate(comment.createdAt),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 0, 10),
            child: Text(comment.content, style: const TextStyle(fontSize: 16)),
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _toggleCommentAmen(index),
              style: TextButton.styleFrom(
                backgroundColor: comment.amened ? appGold : appGray,
                foregroundColor: Colors.black54,
              ),
              child: Text('AMEN (${comment.amenCount})'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final duration = DateTime.now().difference(date.toLocal());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes} minutes ago';
    if (duration.inDays < 1) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
