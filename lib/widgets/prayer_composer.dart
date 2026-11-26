import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_theme.dart';
import 'app_bottom_navigation_bar.dart';

class PrayerDraft {
  final String title;
  final String content;
  final String category;
  final String privacy;

  const PrayerDraft(this.title, this.content, this.category, this.privacy);
}

class PrayerComposer extends StatefulWidget {
  final bool hasTribe;
  final Future<bool> Function(PrayerDraft) onPublish;
  final ValueChanged<int> onNavigate;

  const PrayerComposer({
    super.key,
    required this.hasTribe,
    required this.onPublish,
    required this.onNavigate,
  });

  @override
  State<PrayerComposer> createState() => _PrayerComposerState();
}

class _PrayerComposerState extends State<PrayerComposer> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _speech = SpeechToText();
  String _mode = 'chooser';
  String _privacy = 'public';
  String _category = 'Personal & Family';
  String _locale = 'zh_TW';
  String _transcript = '';
  String? _speechError;
  bool _starting = false;
  bool _listening = false;
  bool _imported = false;
  bool _submitting = false;
  String? _publishError;

  Future<void> _publish() async {
    if (_submitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _publishError = null;
    });
    try {
      final success = await widget.onPublish(
        PrayerDraft(
          _title.text.trim(),
          _content.text.trim(),
          _category,
          _privacy,
        ),
      );
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(
          () => _publishError =
              'Unable to publish. Your draft has been kept. Please try again.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _publishError = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleSpeech() async {
    if (_starting) return;
    if (_speech.isListening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _starting = true;
      _speechError = null;
    });
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _speechError = 'Speech recognition failed: ${error.errorMsg}';
          });
        },
      );
      if (!available) {
        throw StateError(
          'Speech recognition is unavailable. Check microphone permission.',
        );
      }
      if (!mounted || _mode != 'voice') return;
      final locales = await _speech.locales();
      final selected = locales
          .where(
            (item) =>
                item.localeId.replaceAll('-', '_').toLowerCase() ==
                _locale.toLowerCase(),
          )
          .firstOrNull;
      if (selected == null) {
        throw StateError(
          'The selected speech language is unavailable on this device.',
        );
      }
      if (!mounted || _mode != 'voice') return;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: selected.localeId,
          listenFor: const Duration(seconds: 60),
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            final words = result.recognizedWords;
            _transcript = words.length > 500 ? words.substring(0, 500) : words;
          });
        },
      );
      if (mounted) setState(() => _listening = _speech.isListening);
    } catch (error) {
      if (mounted) setState(() => _speechError = error.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _back() async {
    if (_submitting) return;
    if (_mode == 'chooser') {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _mode = 'chooser';
      _listening = false;
    });
    await _speech.cancel();
  }

  @override
  void dispose() {
    _speech.cancel();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: appGray,
    border: const OutlineInputBorder(),
    contentPadding: const EdgeInsets.all(14),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == 'chooser' && !_submitting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (_mode) {
            'text' => 'Create text post',
            'voice' => 'Create voice post',
            _ => 'Create post',
          }),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _mode == 'chooser'
              ? _chooser()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _mode == 'text' ? _textForm() : _voiceForm(),
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          selectedIndex: 2,
          onSelected: (index) {
            if (_submitting) return;
            if (index == 2) {
              _back();
            } else {
              Navigator.of(context).pop();
              widget.onNavigate(index);
            }
          },
        ),
      ),
    );
  }

  Widget _chooser() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: appCream,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 56),
              ),
              onPressed: () => setState(() => _mode = 'text'),
              icon: const Icon(Icons.edit_note),
              label: const Text('Create text post'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: appCream,
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 56),
              ),
              onPressed: () => setState(() => _mode = 'voice'),
              icon: const Icon(Icons.mic_none),
              label: const Text('Create voice post'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _textForm() {
    final categories = [
      'Personal & Family',
      'Church & Ministry',
      'Kingdom Prayer',
      if (widget.hasTribe) 'Tribe Prayer',
    ];
    final privacy = {
      'public': 'Public',
      'family': 'Family',
      if (widget.hasTribe) 'tribe': 'Tribe',
      'individual': 'Individual',
    };
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imported)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Imported from audio',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _privacy,
                  isExpanded: true,
                  decoration: _decoration('Privacy')
                      .copyWith(fillColor: appCream),
                  items: privacy.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _privacy = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: _decoration('Category')
                      .copyWith(fillColor: appCream),
                  items: categories
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, maxLines: 2),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 100,
                  enabled: !_submitting,
                  decoration: _decoration('Title *').copyWith(counterText: ''),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _content,
                  maxLength: 500,
                  minLines: 8,
                  maxLines: 12,
                  enabled: !_submitting,
                  decoration: _decoration('Write your prayer here...'),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Content is required.'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_publishError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _publishError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: appGold,
                    foregroundColor: Colors.black,
                  ),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Post'),
                  onPressed: _submitting ? null : _publish,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
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

  Widget _voiceForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: _locale,
        isExpanded: true,
        decoration: _decoration('Language').copyWith(fillColor: appCream),
        items: const [
          DropdownMenuItem(value: 'zh_TW', child: Text('Chinese (Taiwan)')),
          DropdownMenuItem(value: 'en_US', child: Text('English')),
        ],
        onChanged: _starting || _listening
            ? null
            : (value) {
                if (value != null) setState(() => _locale = value);
              },
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: appCream,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Voice to text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                size: 64,
                color: _listening ? Colors.red : const Color(0xFF26314D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _starting
                  ? 'Preparing...'
                  : _listening
                  ? 'Listening...'
                  : 'Ready to record',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _starting ? null : _toggleSpeech,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? 'Stop recording' : 'Start recording'),
            ),
            if (_speechError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _speechError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(minHeight: 140),
              color: appGray,
              child: SelectableText(
                _transcript.isEmpty
                    ? 'Your transcription will appear here.'
                    : _transcript,
              ),
            ),
            const SizedBox(height: 12),
            Text('${_transcript.length}/500', textAlign: TextAlign.end),
            TextButton.icon(
              onPressed: _starting || _listening
                  ? null
                  : () => setState(() => _transcript = ''),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Re-record'),
            ),
            FilledButton(
              onPressed: _starting || _listening || _transcript.trim().isEmpty
                  ? null
                  : () => setState(() {
                      _content.text = _transcript;
                      _imported = true;
                      _mode = 'text';
                    }),
              child: const Text('Confirm & edit post'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _back,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
        child: const Text('Cancel'),
      ),
    ],
  );
}
