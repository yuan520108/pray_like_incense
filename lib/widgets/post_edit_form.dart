import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/prayer_post.dart';
import '../services/posts_service.dart' show PostsRepository;

class PostEditForm extends StatefulWidget {
  final PrayerPost post;
  final PostsRepository postsRepository;
  final Future<void> Function() onSaved;
  final VoidCallback onCancel;

  const PostEditForm({
    super.key,
    required this.post,
    required this.postsRepository,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<PostEditForm> createState() => _PostEditFormState();
}

class _PostEditFormState extends State<PostEditForm> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.post.title ?? '',
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.post.content,
  );
  bool _isSaving = false;

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty || content.length > 500 || title.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check the title and post length')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.postsRepository.updatePost(
        postId: widget.post.postId,
        title: title.isEmpty ? null : title,
        content: content,
      );
      await widget.onSaved();
      if (mounted) widget.onCancel();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appCream,
        border: Border.symmetric(
          horizontal: BorderSide(color: appYellow, width: 2),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            maxLength: 100,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLength: 500,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appYellow,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('💾 Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
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
        ],
      ),
    );
  }
}
