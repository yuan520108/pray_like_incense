import 'package:flutter/material.dart';
import '../models/prayer_post.dart';

class PostCard extends StatefulWidget {
  final PrayerPost post;
  final bool isPostAuthor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onWitness;
  final VoidCallback? onRefresh;

  const PostCard({
    super.key,
    required this.post,
    required this.isPostAuthor,
    this.onEdit,
    this.onDelete,
    this.onLike,
    this.onComment,
    this.onWitness,
    this.onRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.amenCount;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用者資訊
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.post.avatarUrl ?? ''),
                  radius: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.post.createdAt.toString(), // Simplified for now
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右上角編輯按鈕 (僅限貼文作者)
                if (widget.isPostAuthor)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: widget.onEdit,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 貼文內容
            Text(
              widget.post.content,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            // 貼文圖片（如果有的話）
            if (widget.post.category != null && widget.post.category!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.post.category!, // Using category as placeholder
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            // 按讚、評論、Witness 按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likeCount += _isLiked ? 1 : -1;
                    });
                    widget.onLike?.call();
                  },
                  icon: const Icon(Icons.thumb_up),
                  label: Text(_likeCount.toString()),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onComment,
                  icon: const Icon(Icons.comment),
                  label: const Text('Comment'),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onWitness,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Witness'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}