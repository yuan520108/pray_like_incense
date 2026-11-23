import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pray_like_incense/services/notifications_service.dart';
import 'package:pray_like_incense/services/ycoin_service.dart';

Dio _recordingDio(
  Map<String, dynamic> Function(RequestOptions request) responseFor,
  void Function(RequestOptions request) onRequest,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://testpray.54ucl.com/api/'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest(options);
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
  test('notification feed uses cursor body and parses unread state', () async {
    RequestOptions? request;
    final service = NotificationsService(
      _recordingDio(
        (_) => {
          'status': 'success',
          'data': {
            'items': [
              {
                'notificationId': 'notification-1',
                'messageKey': 'commentedOnPost',
                'notificationType': 'commented_on_post',
                'targetId': 'post-1',
                'targetType': 'post',
                'refId': 'comment-1',
                'refType': 'comment',
                'url': '/posts/post-1',
                'actorName': 'Prayer User',
                'actor': {
                  'userId': 'user-1',
                  'displayName': 'Prayer User',
                  'handle': null,
                  'avatarUrl': null,
                },
                'postTitle': 'A prayer',
                'postPreview': 'Please pray...',
                'isRead': false,
                'count': 1,
                'createdAt': '2026-11-04T10:00:00+00:00',
              },
            ],
            'nextCursor': 'next-page',
            'unreadCount': 3,
          },
        },
        (options) => request = options,
      ),
    );

    final page = await service.getFeed(
      cursor: 'current-page',
      pageSize: 25,
    );

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/notifications/query');
    expect(request!.data, {
      'pageSize': 25,
      'cursor': 'current-page',
    });
    expect(page.items.single.messageKey, 'commentedOnPost');
    expect(page.items.single.isRead, isFalse);
    expect(page.unreadCount, 3);
    expect(page.nextCursor, 'next-page');
  });

  test('notification read endpoint includes an empty JSON object', () async {
    RequestOptions? request;
    final service = NotificationsService(
      _recordingDio(
        (_) => {'status': 'success', 'data': {}},
        (options) => request = options,
      ),
    );

    await service.markRead('notification-1');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/notifications/notification-1/read');
    expect(request!.data, isEmpty);
  });

  test('Y coin reads documented balance and transaction fields', () async {
    final requests = <RequestOptions>[];
    final service = YCoinService(
      _recordingDio(
        (request) => request.path.endsWith('/balance')
            ? {
                'status': 'success',
                'data': {
                  'item': {'balance': '1.25', 'balanceCents': 125},
                },
              }
            : {
                'status': 'success',
                'data': {
                  'items': [
                    {
                      'ycoinTransactionId': 'transaction-1',
                      'amountCents': 25,
                      'contextPostId': 'post-1',
                      'createdAt': '2026-11-04T10:00:00+00:00',
                      'description': 'reward.post',
                      'eventType': 'post',
                      'sourceId': 'post-1',
                    },
                  ],
                },
                'pagination': {
                  'page': 1,
                  'pageSize': 25,
                  'total': 1,
                  'totalPages': 1,
                  'totalRelation': 'eq',
                  'hasNext': false,
                },
              },
        requests.add,
      ),
    );

    final balance = await service.getBalance();
    final transactions = await service.getTransactions();

    expect(balance.balance, '1.25');
    expect(balance.balanceCents, 125);
    expect(requests[0].path, 'v1/ycoin/balance');
    expect(requests[1].path, 'v1/ycoin/transactions/query');
    expect(requests[1].data['fields'], contains('amountCents'));
    expect(transactions.items.single.description, 'reward.post');
    expect(transactions.items.single.amountCents, 25);
  });
}
