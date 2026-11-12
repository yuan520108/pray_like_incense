import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/services/ycoin_service.dart';

Dio _dioReturning(
  Object Function(RequestOptions request) responseFor,
  void Function(RequestOptions request)? onRequest,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://testpray.54ucl.com/api/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: responseFor(options),
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  test(
    'requests the documented balance endpoint and returns live balance',
    () async {
      RequestOptions? request;
      final service = YcoinService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {
              'item': {'balance': '12.75', 'balanceCents': 1275},
            },
          },
          (options) => request = options,
        ),
      );

      final balance = await service.getBalance();

      expect(request!.method, 'GET');
      expect(request!.path, 'v1/ycoin/balance');
      expect(balance, '12.75');
    },
  );

  test(
    'reports malformed balance response instead of showing a default',
    () async {
      final service = YcoinService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {
              'item': {'balance': '12.75', 'balanceCents': '1275'},
            },
          },
          null,
        ),
      );

      expect(service.getBalance(), throwsA(isA<FormatException>()));
    },
  );

  test(
    'queries paginated transaction fields and parses cents as raw cents',
    () async {
      RequestOptions? request;
      final service = YcoinService(
        _dioReturning(
          (_) => {
            'status': 'success',
            'data': {
              'items': [
                {
                  'amountCents': 20,
                  'description': 'reward.amen',
                  'eventType': 'amen',
                  'createdAt': '2026-11-05T05:30:00+00:00',
                },
              ],
            },
            'pagination': {
              'hasNext': true,
              'page': 2,
              'pageSize': 20,
              'total': 21,
              'totalPages': 2,
              'totalRelation': 'eq',
            },
          },
          (options) => request = options,
        ),
      );

      final result = await service.getTransactions(page: 2, pageSize: 20);

      expect(request!.method, 'POST');
      expect(request!.path, 'v1/ycoin/transactions/query');
      expect(request!.data, {
        'fields': [
          'amountCents',
          'contextPostId',
          'createdAt',
          'description',
          'eventType',
          'sourceId',
          'ycoinTransactionId',
        ],
        'pagination': {'page': 2, 'pageSize': 20},
      });
      expect(result.items.single.amountCents, 20);
      expect(result.items.single.description, 'reward.amen');
      expect(result.items.single.eventType, 'amen');
      expect(
        result.items.single.createdAt,
        DateTime.parse('2026-11-05T05:30:00+00:00'),
      );
      expect(result.page, 2);
      expect(result.hasNext, isTrue);
    },
  );
}
