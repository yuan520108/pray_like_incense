import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/ycoin_service.dart';
import '../widgets/app_bottom_navigation_bar.dart';

class YcoinHistoryPage extends StatefulWidget {
  final YcoinRepository repository;
  final String? balance;
  final ValueChanged<int> onNavigate;

  const YcoinHistoryPage({
    super.key,
    required this.repository,
    required this.balance,
    required this.onNavigate,
  });

  @override
  State<YcoinHistoryPage> createState() => _YcoinHistoryPageState();
}

class _YcoinHistoryPageState extends State<YcoinHistoryPage> {
  static const _pageSize = 20;

  final List<YcoinTransaction> _transactions = [];
  String? _balance;
  String? _balanceError;
  bool _isBalanceLoading = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _balance = widget.balance;
    _loadBalance();
    _loadTransactions();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isBalanceLoading = true;
      _balanceError = null;
    });

    try {
      final balance = await widget.repository.getBalance();
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _isBalanceLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _balanceError = error.toString().replaceFirst('Exception: ', '');
        _isBalanceLoading = false;
      });
    }
  }

  Future<void> _loadTransactions({bool loadMore = false}) async {
    if (_isLoadingMore || (loadMore && !_hasNext)) return;

    setState(() {
      _error = null;
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _transactions.clear();
        _page = 1;
      }
    });

    try {
      final result = await widget.repository.getTransactions(
        page: loadMore ? _page + 1 : 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _transactions.addAll(result.items);
        _page = result.page;
        _hasNext = result.hasNext;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildHistory()),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 0,
        onSelected: (index) {
          widget.onNavigate(index);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 20),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('ycoin-history-back'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Yield to God Coins (YC)\nHistorical record',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'serif',
                fontSize: 20,
                height: 1.25,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('ycoin-history-balance'),
            onTap: _balanceError == null ? null : _loadBalance,
            child: Tooltip(
              message: _balanceError ?? 'Ycoin balance',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD000),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FFD000),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings, color: appIconBrown, size: 23),
                    const SizedBox(width: 7),
                    Text(
                      _isBalanceLoading && _balance == null
                          ? '…'
                          : _balanceError != null && _balance == null
                          ? '!'
                          : _balance ?? '—',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: appSelected));
    }

    if (_error != null && _transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadTransactions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          'No Ycoin records yet.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        _sectionLabel('YC recently achieved a record'),
        const SizedBox(height: 16),
        _transactionCard(_transactions.first, recent: true),
        if (_transactions.length > 1) ...[
          const SizedBox(height: 48),
          _sectionLabel('Past historical record'),
          const SizedBox(height: 16),
          ..._transactions.skip(1).map(_transactionCard),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
        if (_hasNext || _isLoadingMore) ...[
          const SizedBox(height: 16),
          Center(
            child: _isLoadingMore
                ? const CircularProgressIndicator(color: appSelected)
                : OutlinedButton(
                    onPressed: () => _loadTransactions(loadMore: true),
                    child: const Text('Load more records'),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'serif',
          fontSize: 16,
        ),
      ),
    ),
  );

  Widget _transactionCard(YcoinTransaction transaction, {bool recent = false}) {
    final title = _operationTitle(transaction);
    final amount = _formatAmount(transaction.amountCents);
    final date = _formatDate(transaction.createdAt);

    return Container(
      key: ValueKey(
        'ycoin-transaction-${transaction.createdAt?.toIso8601String()}-$title-$amount',
      ),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(18),
        border: recent
            ? Border.all(color: const Color(0xFFFFD000), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              _operationIcon(transaction),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  recent ? _relativeTime(transaction.createdAt) : date,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F5E8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF388044),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _operationTitle(YcoinTransaction transaction) {
    switch (transaction.description ?? transaction.eventType) {
      case 'reward.post':
      case 'post':
        return '📝 create post';
      case 'reward.comment':
      case 'comment':
        return '💬 Comment';
      case 'reward.witness':
      case 'witness':
        return '🙏 Witness';
      case 'reward.amen':
      case 'amen':
        return '🙏 Amen';
      default:
        return 'Ycoin transaction';
    }
  }

  String _operationIcon(YcoinTransaction transaction) {
    switch (transaction.description ?? transaction.eventType) {
      case 'reward.post':
      case 'post':
        return '📝';
      case 'reward.comment':
      case 'comment':
        return '💬';
      case 'reward.witness':
      case 'witness':
        return '🙏';
      case 'reward.amen':
      case 'amen':
        return '🙏';
      default:
        return '🪙';
    }
  }

  String _formatAmount(int? amountCents) {
    if (amountCents == null) return '—';
    final magnitude = amountCents.abs();
    final whole = magnitude ~/ 100;
    final cents = magnitude % 100;
    final value = cents == 0
        ? '$whole'
        : cents % 10 == 0
        ? '$whole.${cents ~/ 10}'
        : '$whole.${cents.toString().padLeft(2, '0')}';
    final sign = amountCents > 0
        ? '+'
        : amountCents < 0
        ? '-'
        : '';
    return '$sign$value';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return 'Time unavailable';
    final elapsed = DateTime.now().difference(date.toLocal());
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} minutes ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} hours ago';
    if (elapsed.inDays < 30) return '${elapsed.inDays} days ago';
    return _formatDate(date);
  }
}
