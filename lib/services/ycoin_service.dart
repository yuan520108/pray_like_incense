import 'package:dio/dio.dart';

class YCoinService {
  final Dio _dio;

  YCoinService(this._dio);

  Future<YCoinBalance> getBalance() async {
    try {
      final response = await _dio.get('v1/ycoin/balance');
      final body = _asMap(response.data, 'Y Coin balance response');
      final data = _asMap(body['data'], 'Y Coin balance response data');
      return YCoinBalance.fromJson(
        _asMap(data['item'], 'Y Coin balance response item'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load Y Coin balance', error);
    }
  }

  Future<YCoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 25,
  }) async {
    try {
      final response = await _dio.post(
        'v1/ycoin/transactions/query',
        data: {
          'fields': [
            'amountCents',
            'contextPostId',
            'createdAt',
            'description',
            'eventType',
            'sourceId',
            'ycoinTransactionId',
          ],
          'pagination': {'page': page, 'pageSize': pageSize},
        },
      );
      return YCoinTransactionPage.fromJson(
        _asMap(response.data, 'Y Coin transaction list response'),
      );
    } on DioException catch (error) {
      throw _apiError('Failed to load Y Coin transactions', error);
    }
  }

  Exception _apiError(String action, DioException error) {
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return Exception('$action：${body['message']}');
    }
    if (error.response?.statusCode != null) {
      return Exception('$action（HTTP ${error.response!.statusCode}）');
    }
    return Exception('$action：${error.message ?? error.type.name}');
  }
}

class YCoinBalance {
  final String balance;
  final int balanceCents;

  const YCoinBalance({required this.balance, required this.balanceCents});

  factory YCoinBalance.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'];
    final balanceCents = json['balanceCents'];
    if (balance is! String || balanceCents is! int) {
      throw const FormatException(
        'Y Coin balance fields have an invalid format.',
      );
    }
    return YCoinBalance(balance: balance, balanceCents: balanceCents);
  }
}

class YCoinTransactionPage {
  final List<YCoinTransaction> items;
  final int currentPage;
  final int totalPages;

  const YCoinTransactionPage({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });

  factory YCoinTransactionPage.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data'], 'Y Coin transaction list response data');
    final rawItems = data['items'];
    final pagination = _asMap(
      json['pagination'],
      'Y Coin transaction list response pagination',
    );
    if (rawItems is! List) {
      throw const FormatException(
        'Y Coin transaction list data.items must be a list.',
      );
    }
    return YCoinTransactionPage(
      items: rawItems
          .map(
            (item) => YCoinTransaction.fromJson(
              _asMap(item, 'Y Coin transaction list item'),
            ),
          )
          .toList(growable: false),
      currentPage: _requiredInt(pagination, 'page'),
      totalPages: _requiredInt(pagination, 'totalPages'),
    );
  }
}

class YCoinTransaction {
  final String id;
  final int amountCents;
  final String description;
  final String eventType;
  final DateTime createdAt;
  final String? contextPostId;

  const YCoinTransaction({
    required this.id,
    required this.amountCents,
    required this.description,
    required this.eventType,
    required this.createdAt,
    required this.contextPostId,
  });

  factory YCoinTransaction.fromJson(Map<String, dynamic> json) {
    final contextPostId = json['contextPostId'];
    if (contextPostId != null && contextPostId is! String) {
      throw const FormatException(
        'Y Coin transaction contextPostId is invalid.',
      );
    }
    final createdAt = DateTime.tryParse(_requiredString(json, 'createdAt'));
    if (createdAt == null) {
      throw const FormatException(
        'Y Coin transaction createdAt date has an invalid format.',
      );
    }
    return YCoinTransaction(
      id: _requiredString(json, 'ycoinTransactionId'),
      amountCents: _requiredInt(json, 'amountCents'),
      description: _requiredString(json, 'description'),
      eventType: _requiredString(json, 'eventType'),
      createdAt: createdAt,
      contextPostId: contextPostId as String?,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value, String field) {
  if (value is! Map) {
    throw FormatException('$field must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Field $key has an invalid format.');
  }
  return value;
}
