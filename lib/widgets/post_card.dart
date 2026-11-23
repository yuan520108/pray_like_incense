import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/prayer_post.dart';
import '../services/posts_service.dart' as posts;

typedef CommentsPanelBuilder =
    Widget Function(VoidCallback onClose, Future<void> Function() onCreated);
typedef WitnessPanelBuilder = Widget Function(VoidCallback onClose);
typedef EditPanelBuilder = Widget Function(VoidCallback onClose);

class PostCard extends StatefulWidget {
  final PrayerPost post;
  final bool isPostAuthor;
  final Future<posts.AmenResult> Function()? onLike;
  final Future<void> Function()? onCommentAdded;
  final CommentsPanelBuilder? commentsBuilder;
  final WitnessPanelBuilder? witnessComposerBuilder;
  final EditPanelBuilder? editFormBuilder;
  final Widget? embeddedWitness;

  const PostCard({
    super.key,
    required this.post,
    required this.isPostAuthor,
    this.onLike,
    this.onCommentAdded,
    this.commentsBuilder,
    this.witnessComposerBuilder,
    this.editFormBuilder,
    this.embeddedWitness,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isAmened;
  late int _amenCount;
  late int _commentCount;
  bool _isUpdatingAmen = false;
  bool _showComments = false;
  bool _showWitnessComposer = false;
  bool _showEditForm = false;

  @override
  void initState() {
    super.initState();
    _isAmened = widget.post.amened;
    _amenCount = widget.post.amenCount;
    _commentCount = widget.post.commentCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.amenCount != widget.post.amenCount ||
        oldWidget.post.amened != widget.post.amened) {
      _isAmened = widget.post.amened;
      _amenCount = widget.post.amenCount;
    }
    if (oldWidget.post.commentCount != widget.post.commentCount) {
      _commentCount = widget.post.commentCount;
    }
  }

  Future<void> _toggleAmen() async {
    if (_isUpdatingAmen || widget.onLike == null) return;
    setState(() => _isUpdatingAmen = true);
    try {
      final result = await widget.onLike!.call();
      if (!mounted) return;
      setState(() {
        _isAmened = result.amened;
        _amenCount = result.amenCount;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isUpdatingAmen = false);
    }
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      if (_showComments) _showWitnessComposer = false;
    });
  }

  void _toggleWitnessComposer() {
    setState(() {
      _showWitnessComposer = !_showWitnessComposer;
      if (_showWitnessComposer) _showComments = false;
    });
  }

  void _toggleEditForm() {
    setState(() {
      _showEditForm = !_showEditForm;
      if (_showEditForm) {
        _showComments = false;
        _showWitnessComposer = false;
      }
    });
  }

  Future<void> _onCommentCreated() async {
    if (mounted) setState(() => _commentCount++);
    await widget.onCommentAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isWitnessed = widget.post.witnessed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          if (widget.post.title != null &&
              widget.post.title!.trim().isNotEmpty) ...[
            Text(
              widget.post.title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            widget.post.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF353535),
            ),
          ),
          if (_showEditForm && widget.editFormBuilder != null)
            widget.editFormBuilder!(_toggleEditForm),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E2E2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'AMEN ($_amenCount)',
                  selected: _isAmened,
                  onPressed: _isUpdatingAmen ? null : _toggleAmen,
                  leading: _isUpdatingAmen
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionButton(
                  label: 'PRAY FOR ME ($_commentCount)',
                  selected: _showComments,
                  onPressed: widget.commentsBuilder == null
                      ? null
                      : _toggleComments,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionButton(
                  label: isWitnessed ? '✨ WITNESSED' : 'WITNESS',
                  selected: isWitnessed || widget.isPostAuthor,
                  onPressed:
                      !widget.isPostAuthor ||
                          widget.witnessComposerBuilder == null
                      ? null
                      : _toggleWitnessComposer,
                ),
              ),
            ],
          ),
          if (widget.embeddedWitness != null) ...[
            const SizedBox(height: 22),
            const Divider(height: 1, color: Color(0xFFE2E2E2), thickness: 2),
            const SizedBox(height: 18),
            widget.embeddedWitness!,
          ],
          if (_showComments && widget.commentsBuilder != null)
            widget.commentsBuilder!(_toggleComments, _onCommentCreated),
          if (_showWitnessComposer && widget.witnessComposerBuilder != null)
            widget.witnessComposerBuilder!(_toggleWitnessComposer),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF9DC8FF),
          backgroundImage: widget.post.avatarUrl == null
              ? null
              : NetworkImage(widget.post.avatarUrl!),
          child: widget.post.avatarUrl == null
              ? const Icon(Icons.person, color: Color(0xFF2874D0), size: 31)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post.authorName ?? 'Unknown User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(widget.post.createdAt),
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                spacing: 5,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  _infoPill(_privacyLabel(widget.post.privacy)),
                  if (widget.post.category != null)
                    _infoPill(widget.post.category!),
                ],
              ),
              if (widget.isPostAuthor && widget.editFormBuilder != null)
                SizedBox(
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Edit post',
                    onPressed: _toggleEditForm,
                    icon: const Text('✏️', style: TextStyle(fontSize: 18)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoPill(String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x26FFD700),
        border: Border.all(color: const Color(0x4DFFD700)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFE5C200),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
    Widget? leading,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: selected && onPressed != null ? 2 : 0,
          backgroundColor: selected ? appGold : appGray,
          disabledBackgroundColor: selected ? appGold : appGray,
          foregroundColor: Colors.black54,
          disabledForegroundColor: Colors.black54,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 4)],
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  String _privacyLabel(String privacy) {
    return switch (privacy) {
      'public' => 'PUBLIC',
      'family' => 'FAMILY',
      'tribe' => 'TRIBE',
      'individual' => 'PRIVATE',
      _ => privacy.toUpperCase(),
    };
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
