import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/profile_service.dart';

enum _TribeScreen { overview, detail, introduction, selection }

class TribePage extends StatefulWidget {
  final int? selectedTribeCode;
  final ProfileService profileService;

  const TribePage({
    super.key,
    required this.selectedTribeCode,
    required this.profileService,
  });

  @override
  State<TribePage> createState() => _TribePageState();
}

class _TribePageState extends State<TribePage> {
  late _TribeScreen _screen;
  late Future<TribeInfo>? _tribeFuture;
  List<TribeInfo>? _tribes;
  Object? _tribesError;
  int _currentPage = 0;
  int? _selectedTribeCode;
  bool _hasViewedIntroduction = false;
  bool _isLoadingTribes = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _screen = widget.selectedTribeCode == null
        ? _TribeScreen.overview
        : _TribeScreen.detail;
    _selectedTribeCode = widget.selectedTribeCode;
    _tribeFuture = widget.selectedTribeCode == null
        ? null
        : widget.profileService.getTribe(widget.selectedTribeCode!);
  }

  void _goBack() {
    if (_isSubmitting) return;
    if (_screen == _TribeScreen.overview || _screen == _TribeScreen.detail) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _screen = _TribeScreen.overview);
  }

  Future<void> _openIntroduction() async {
    setState(() {
      _screen = _TribeScreen.introduction;
      _hasViewedIntroduction = true;
    });
    await _loadTribes();
  }

  Future<void> _openSelection() async {
    if (!_hasViewedIntroduction) {
      _showMessage('Please view the Tribes Introduction first.');
      return;
    }
    setState(() => _screen = _TribeScreen.selection);
    await _loadTribes();
  }

  Future<void> _loadTribes() async {
    if (_tribes != null || _isLoadingTribes) return;
    setState(() {
      _isLoadingTribes = true;
      _tribesError = null;
    });
    try {
      final tribes = await widget.profileService.getTribes();
      if (!mounted) return;
      setState(() {
        _tribes = tribes;
        _isLoadingTribes = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tribesError = error;
        _isLoadingTribes = false;
      });
    }
  }

  Future<void> _retryTribeDetails() async {
    final code = widget.selectedTribeCode;
    if (code == null) return;
    setState(() {
      _tribeFuture = widget.profileService.getTribe(code);
    });
  }

  Future<void> _retryTribeList() async {
    setState(() {
      _tribes = null;
      _tribesError = null;
    });
    await _loadTribes();
  }

  Future<void> _confirmSelection() async {
    final tribeCode = _selectedTribeCode;
    if (tribeCode == null || _isSubmitting) return;
    final tribe = _tribes
        ?.where((item) => item.tribeCode == tribeCode)
        .firstOrNull;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Sacred Calling'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FINAL WARNING',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Your selection "${tribe?.nameEn ?? 'Tribe'}"'),
            const SizedBox(height: 12),
            const Text('Please read carefully:'),
            const SizedBox(height: 8),
            const Text(
              'No changes allowed\n'
              'No second chances\n'
              'No undo option\n\n'
              'This is your final choice. Think twice before confirming.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final profile = await widget.profileService.updateTribe(tribeCode);
      if (!mounted) return;
      final savedTribeCode = profile.tribeCode;
      if (savedTribeCode == null) {
        throw const FormatException(
          'The server did not return the saved tribe code.',
        );
      }
      Navigator.of(context).pop(savedTribeCode);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !_isSubmitting &&
          (_screen == _TribeScreen.overview || _screen == _TribeScreen.detail),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(switch (_screen) {
            _TribeScreen.overview => 'Tribe',
            _TribeScreen.detail => 'Tribe Details',
            _TribeScreen.introduction => '12 Tribes Introduction',
            _TribeScreen.selection => '12 Tribes List',
          }),
        ),
        body: SafeArea(
          top: false,
          child: switch (_screen) {
            _TribeScreen.overview => _buildNoTribeOverview(),
            _TribeScreen.detail => _buildTribeDetail(),
            _TribeScreen.introduction => _buildIntroduction(),
            _TribeScreen.selection => _buildSelection(),
          },
        ),
      ),
    );
  }

  Widget _buildNoTribeOverview() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFD9D9D9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '?',
                  style: TextStyle(color: Colors.black54, fontSize: 36),
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  children: [
                    _StatusBox(text: 'not have'),
                    SizedBox(height: 8),
                    _StatusBox(text: 'Status: not Active'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _TribeAction(
            title: '12 Tribes Introduction',
            enabled: true,
            onTap: _openIntroduction,
          ),
          const SizedBox(height: 14),
          _TribeAction(
            title: '12 Tribes List',
            enabled: _hasViewedIntroduction,
            onTap: _openSelection,
          ),
        ],
      ),
    );
  }

  Widget _buildTribeDetail() {
    final future = _tribeFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<TribeInfo>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: appGold));
        }
        if (snapshot.hasError) {
          return _TribeErrorState(
            message: snapshot.error.toString(),
            onRetry: _retryTribeDetails,
          );
        }
        final tribe = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                _TribeIcon(tribe: tribe, size: 84),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tribe.nameEn} ${tribe.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Status: Active',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: appCream,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                tribe.descriptionEn,
                style: const TextStyle(
                  color: Color(0xFF26314D),
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIntroduction() {
    if (_isLoadingTribes) {
      return const Center(child: CircularProgressIndicator(color: appGold));
    }
    if (_tribesError != null) {
      return _TribeErrorState(
        message: _tribesError.toString(),
        onRetry: _retryTribeList,
      );
    }
    final tribes = _tribes ?? const <TribeInfo>[];
    if (tribes.isEmpty) return const _EmptyTribes();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Discover Your Spiritual Heritage',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose from 12 Sacred Tribes',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        for (final tribe in tribes) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: appCream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: appCream,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: _TribeIcon(tribe: tribe, size: 56),
                title: Text(
                  '${tribe.nameEn} ${tribe.badge}',
                  style: const TextStyle(
                    color: Color(0xFF26314D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: SelectableText(
                      tribe.descriptionEn,
                      style: const TextStyle(
                        color: Color(0xFF26314D),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelection() {
    if (_isLoadingTribes) {
      return const Center(child: CircularProgressIndicator(color: appGold));
    }
    if (_tribesError != null) {
      return _TribeErrorState(
        message: _tribesError.toString(),
        onRetry: _retryTribeList,
      );
    }
    final tribes = _tribes ?? const <TribeInfo>[];
    if (tribes.isEmpty) return const _EmptyTribes();

    final pageCount = (tribes.length / 6).ceil();
    final pageItems = tribes.skip(_currentPage * 6).take(6).toList();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Column(
            children: [
              Text(
                'Discover Your Spiritual Heritage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Choose from 12 Sacred Tribes',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pageItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width < 380 ? 2 : 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 140,
            ),
            itemBuilder: (context, index) {
              final tribe = pageItems[index];
              final selected = _selectedTribeCode == tribe.tribeCode;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isSubmitting
                    ? null
                    : () =>
                          setState(() => _selectedTribeCode = tribe.tribeCode),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? appGold : appCream,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TribeIcon(tribe: tribe, size: 58),
                      const SizedBox(height: 8),
                      Text(
                        tribe.nameEn,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF26314D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: _currentPage == 0
                    ? null
                    : () => setState(() => _currentPage--),
                icon: const Icon(Icons.chevron_left),
                color: Colors.white,
                disabledColor: Colors.white38,
              ),
              for (var index = 0; index < pageCount; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    _currentPage == index
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              IconButton(
                tooltip: 'Next page',
                onPressed: _currentPage >= pageCount - 1
                    ? null
                    : () => setState(() => _currentPage++),
                icon: const Icon(Icons.chevron_right),
                color: Colors.white,
                disabledColor: Colors.white38,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedTribeCode == null || _isSubmitting
                  ? null
                  : _confirmSelection,
              style: FilledButton.styleFrom(
                backgroundColor: appGold,
                foregroundColor: const Color(0xFF26314D),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('CONTINUE'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String text;

  const _StatusBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TribeAction extends StatelessWidget {
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  const _TribeAction({
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? appCream : Colors.white24,
          foregroundColor: enabled ? const Color(0xFF26314D) : Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(title),
      ),
    );
  }
}

class _TribeIcon extends StatelessWidget {
  final TribeInfo tribe;
  final double size;

  const _TribeIcon({required this.tribe, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: appGold.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/images/tribes/${tribe.slug.toLowerCase()}.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            tribe.nameEn.isEmpty ? '?' : tribe.nameEn[0],
            style: TextStyle(
              color: const Color(0xFF26314D),
              fontSize: size * 0.42,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _TribeErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _TribeErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyTribes extends StatelessWidget {
  const _EmptyTribes();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'No tribes are available.',
      style: TextStyle(color: Colors.white),
    ),
  );
}
