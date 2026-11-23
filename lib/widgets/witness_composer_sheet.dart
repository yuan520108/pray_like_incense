import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import '../services/media_service.dart';
import '../services/witness_service.dart';

class WitnessComposer extends StatefulWidget {
  final String postId;
  final WitnessService witnessService;
  final MediaService mediaService;
  final Future<void> Function() onWitnessCreated;
  final VoidCallback onCancel;

  const WitnessComposer({
    super.key,
    required this.postId,
    required this.witnessService,
    required this.mediaService,
    required this.onWitnessCreated,
    required this.onCancel,
  });

  @override
  State<WitnessComposer> createState() => _WitnessComposerState();
}

class _WitnessComposerState extends State<WitnessComposer> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSending = false;

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > MediaService.maxImageBytes) {
        throw const FormatException('Image cannot exceed 10 MiB');
      }
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _imageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _sendWitness() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      String? imageMediaId;
      if (_selectedImage != null) {
        final uploaded = await widget.mediaService.uploadImage(
          _selectedImage!,
          purpose: 'witness',
        );
        imageMediaId = uploaded.mediaId;
      }
      await widget.witnessService.createWitness(
        postId: widget.postId,
        content: content,
        imageMediaId: imageMediaId,
      );
      await widget.onWitnessCreated();
      if (mounted) widget.onCancel();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isContentEmpty = _contentController.text.trim().isEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        border: Border.all(color: appYellow, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _contentController,
            maxLength: 5000,
            minLines: 4,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Share your testimony...',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_imageBytes!, height: 180, fit: BoxFit.cover),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isSending ? null : _pickImage,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _selectedImage == null
                    ? 'Add photo (optional)'
                    : 'Change photo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black54,
                side: const BorderSide(color: Colors.black26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isSending || isContentEmpty ? null : _sendWitness,
            style: ElevatedButton.styleFrom(
              backgroundColor: appYellow,
              disabledBackgroundColor: const Color(0xFFFFE986),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('✨ Submit Testimony'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isSending ? null : widget.onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: appGray,
              foregroundColor: Colors.black54,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
