import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pray_like_incense/services/friends_service.dart';

Dio _dioReturning(
  Map<String, dynamic> Function(RequestOptions request) responseFor,
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
  test('friend search sends documented query and parses relation', () async {
    RequestOptions? request;
    final service = FriendsService(
      _dioReturning(
        (_) => {
          'status': 'success',
          'data': {
            'items': [
              {
                'userId': 'user-2',
                'displayName': 'Friend',
                'handle': 'friend',
                'avatarUrl': null,
                'tribeCode': 1,
                'relation': 'none',
              },
            ],
          },
        },
        (options) => request = options,
      ),
    );

    final results = await service.searchUsers(query: 'friend');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/friends/search');
    expect(request!.data, {'query': 'friend', 'size': 20});
    expect(results.single.userId, 'user-2');
    expect(results.single.relation, 'none');
  });

  test('friend invitations send target id and parse accepted state', () async {
    RequestOptions? request;
    final service = FriendsService(
      _dioReturning(
        (_) => {
          'status': 'success',
          'data': {
            'item': {'alreadyFriends': false, 'autoAccepted': false},
          },
        },
        (options) => request = options,
      ),
    );

    final result = await service.sendInvitation(targetUserId: 'user-2');

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/friends/invitations');
    expect(request!.data, {'targetUserId': 'user-2'});
    expect(result.alreadyFriends, isFalse);
    expect(result.autoAccepted, isFalse);
  });
}
