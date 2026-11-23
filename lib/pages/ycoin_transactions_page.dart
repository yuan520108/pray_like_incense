import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/ycoin_service.dart';
import '../widgets/app_bottom_navigation_bar.dart';

class YCoinTransactionsPage extends StatefulWidget {
  final YCoinService yCoinService;
  final ValueChanged<int> onNavigate;

  const YCoinTransactionsPage({
    super.key,
    required this.yCoinService,
    required this.onNavigate,
  });

  @override
  State<YCoinTransactionsPage> createState() => _YCoinTransactionsPageState();
}

class _YCoinTransactionsPageState extends State<YCoinTransactionsPage> {
  final List<YCoinTransaction> _transactions = [];
  int _page = 1;
  int _totalPages = 1;
  String? _balance;
  bool _isLoading = false;
  String? _errorMessage;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadTransactions();
  }

  Future<void> _loadBalance() async {
    try {
      final result = await widget.yCoinService.getBalance();
      if (!mounted) return;
      setState(() {
        _balance = result.balance;
        _balanceError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _balanceError = error.toString());
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _transactions.clear();
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.yCoinService.getTransactions(page: _page);
      if (!mounted) return;
      setState(() {
        _transactions.addAll(result.items);
        _page = result.currentPage + 1;
        _totalPages = result.totalPages;
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

  @override
  Widget build(BuildContext context) {
    final recent = _transactions.isEmpty ? null : _transactions.first;
    final history = _transactions.length < 2
        ? const <YCoinTransaction>[]
        : _transactions.sublist(1);

    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: appBackground,
        foregroundColor: Colors.white,
        toolbarHeight: 82,
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Yield to God Coins (YC)\nHistorical record',
                style: TextStyle(fontFamily: 'serif', fontSize: 17),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: appYellow,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    _balance ?? (_balanceError == null ? '--' : '—'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadBalance(), _loadTransactions(refresh: true)]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          children: [
            if (_balanceError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _balanceError!,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadBalance,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (recent != null) ...[
              _sectionHeader('YC recently achieved a record'),
              const SizedBox(height: 16),
              _transactionCard(recent, highlighted: true),
              const SizedBox(height: 50),
              _sectionHeader('Past historical record'),
              const SizedBox(height: 16),
              for (final item in history) ...[
                _transactionCard(item),
                const SizedBox(height: 16),
              ],
            ] else if (_isLoading) ...[
              const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator(color: appGold)),
              ),
            ] else if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              TextButton(
                onPressed: _loadTransactions,
                child: const Text('Retry'),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No Y coin transactions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
            if (_isLoading && _transactions.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: appGold)),
              )
            else if (_errorMessage != null && _transactions.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: _loadTransactions,
                  child: const Text('Retry'),
                ),
              )
            else if (_transactions.isNotEmpty && _page <= _totalPages)
              Center(
                child: OutlinedButton(
                  onPressed: _loadTransactions,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Load more'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: -1,
        onSelected: widget.onNavigate,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: appSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'serif',
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _transactionCard(YCoinTransaction item, {bool highlighted = false}) {
    final color = item.amountCents >= 0
        ? const Color(0xFF16833E)
        : const Color(0xFFB32A2A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: appCream,
        borderRadius: BorderRadius.circular(20),
        border: highlighted ? Border.all(color: appYellow, width: 3) : null,
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
              _iconFor(item.description),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _description(item.description),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatAmount(item.amountCents),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _iconFor(String description) {
    return switch (description) {
      'reward.post' => '📝',
      'reward.comment' => '💬',
      'reward.witness' => '✨',
      'reward.amen' => '🙏',
      _ => '🪙',
    };
  }

  String _description(String description) {
    return switch (description) {
      'reward.post' => 'create post',
      'reward.comment' => 'Comment',
      'reward.witness' => 'Witness',
      'reward.amen' => 'Amen',
      _ => description,
    };
  }

  String _formatAmount(int cents) {
    final value = cents / 100;
    final decimals = cents % 100 == 0 ? 0 : (cents % 10 == 0 ? 1 : 2);
    final sign = cents >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}';
  }

  String _formatDate(DateTime date) {
    final duration = DateTime.now().difference(date.toLocal());
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes} minutes ago';
    if (duration.inDays < 1) return '${duration.inHours} hours ago';
    if (duration.inDays < 7) return '${duration.inDays} days ago';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
