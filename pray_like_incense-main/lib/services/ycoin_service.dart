import 'package:dio/dio.dart';

abstract interface class YcoinRepository {
  Future<String> getBalance();

  Future<YcoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 20,
  });
}

class YcoinService implements YcoinRepository {
  final Dio _dio;

  YcoinService(this._dio);

  @override
  Future<String> getBalance() async {
    try {
      final response = await _dio.get('v1/ycoin/balance');
      final body = _asMap(response.data, 'Ycoin balance response');
      final data = _asMap(body['data'], 'Ycoin balance response data');
      final item = _asMap(data['item'], 'Ycoin balance response item');
      final balance = item['balance'];
      final balanceCents = item['balanceCents'];

      if (balance is! String || balance.isEmpty) {
        throw const FormatException(
          'Ycoin balance must be a non-empty string.',
        );
      }
      if (balanceCents is! int) {
        throw const FormatException('Ycoin balanceCents must be an integer.');
      }

      return balance;
    } on DioException catch (error) {
      if (error.response?.statusCode != null) {
        throw Exception(
          'Failed to load Ycoin balance (HTTP ${error.response!.statusCode}).',
        );
      }
      throw Exception(
        'Failed to load Ycoin balance: ${error.message ?? error.type.name}',
      );
    }
  }

  @override
  Future<YcoinTransactionPage> getTransactions({
    int page = 1,
    int pageSize = 20,
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
      final body = _asMap(response.data, 'Ycoin transactions response');
      final data = _asMap(body['data'], 'Ycoin transactions response data');
      final rawItems = data['items'];
      if (rawItems is! List) {
        throw const FormatException(
          'Ycoin transactions data.items must be an array.',
        );
      }

      final pagination = _asMap(
        body['pagination'],
        'Ycoin transactions response pagination',
      );
      final hasNext = pagination['hasNext'];
      final responsePage = pagination['page'];
      if (hasNext is! bool || responsePage is! int) {
        throw const FormatException(
          'Ycoin transaction pagination data is invalid.',
        );
      }

      return YcoinTransactionPage(
        items: rawItems
            .map(
              (item) =>
                  YcoinTransaction.fromJson(_asMap(item, 'Ycoin transaction')),
            )
            .toList(growable: false),
        page: responsePage,
        hasNext: hasNext,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != null) {
        throw Exception(
          'Failed to load Ycoin transactions (HTTP ${error.response!.statusCode}).',
        );
      }
      throw Exception(
        'Failed to load Ycoin transactions: ${error.message ?? error.type.name}',
      );
    }
  }
}

class YcoinTransactionPage {
  final List<YcoinTransaction> items;
  final int page;
  final bool hasNext;

  const YcoinTransactionPage({
    required this.items,
    required this.page,
    required this.hasNext,
  });
}

class YcoinTransaction {
  final int? amountCents;
  final String? description;
  final String? eventType;
  final DateTime? createdAt;

  const YcoinTransaction({
    required this.amountCents,
    required this.description,
    required this.eventType,
    required this.createdAt,
  });

  factory YcoinTransaction.fromJson(Map<String, dynamic> json) {
    final amountCents = json['amountCents'];
    final description = json['description'];
    final eventType = json['eventType'];
    final createdAtValue = json['createdAt'];

    if (amountCents != null && amountCents is! int) {
      throw const FormatException('Ycoin amountCents must be an integer.');
    }
    if (description != null && description is! String) {
      throw const FormatException('Ycoin description must be a string.');
    }
    if (eventType != null && eventType is! String) {
      throw const FormatException('Ycoin eventType must be a string.');
    }
    if (createdAtValue != null && createdAtValue is! String) {
      throw const FormatException('Ycoin createdAt must be a string.');
    }

    final createdAt = createdAtValue == null
        ? null
        : DateTime.tryParse(createdAtValue as String);
    if (createdAtValue != null && createdAt == null) {
      throw const FormatException('Ycoin createdAt date is invalid.');
    }

    return YcoinTransaction(
      amountCents: amountCents as int?,
      description: description as String?,
      eventType: eventType as String?,
      createdAt: createdAt,
    );
  }
}

Map<String, dynamic> _asMap(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('$label must be an object');
  }
  return Map<String, dynamic>.from(value);
}
