import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pray_like_incense/pages/tribe_page.dart';
import 'package:pray_like_incense/services/profile_service.dart';

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

Map<String, dynamic> _profileResponse({int? tribeCode}) => {
  'data': {
    'item': {
      'avatarUrl': null,
      'displayName': 'Prayer User',
      'handle': 'prayer_user',
      'profileComplete': true,
      'tribeCode': tribeCode,
      'userId': 'user-1',
    },
  },
};

Map<String, dynamic> _tribeJson() => {
  'badge': '🦁',
  'descriptionEn': 'A tribe description.',
  'imageKey': 'judah',
  'nameEn': 'Judah',
  'nameZh': 'Judah',
  'slug': 'judah',
  'tribeCode': 1,
};

void main() {
  test(
    'avatar upload saves through the authenticated multipart endpoint',
    () async {
      RequestOptions? request;
      final service = ProfileService(
        _dioReturning(
          (_) => {
            'profile': {'avatar_url': '/uploads/avatar.png'},
          },
          (options) => request = options,
        ),
      );
      final url = await service.uploadAvatar(
        XFile.fromData(Uint8List.fromList([1, 2, 3])),
      );
      expect(request!.path, 'auth/profile/avatar');
      expect(request!.method, 'POST');
      expect(request!.contentType, 'multipart/form-data');
      final form = request!.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.length, 3);
      expect(form.fields.single.key, 'avatar_url');
      expect(form.fields.single.value, '');
      expect(url, '/uploads/avatar.png');
    },
  );

  test('avatar upload rejects a missing saved URL', () async {
    final service = ProfileService(_dioReturning((_) => {}, null));
    await expectLater(
      service.uploadAvatar(XFile.fromData(Uint8List.fromList([1]))),
      throwsFormatException,
    );
  });

  testWidgets('tribe introduction expands and selection fits a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = ProfileService(
      _dioReturning(
        (_) => {
          'data': {
            'items': [_tribeJson()],
          },
        },
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TribePage(selectedTribeCode: null, profileService: service),
      ),
    );
    await tester.tap(find.text('12 Tribes Introduction').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('A tribe description.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 Tribes List'));
    await tester.pumpAndSettle();
    expect(find.text('Judah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('profile reads documented current-profile route', () async {
    RequestOptions? request;
    final service = ProfileService(
      _dioReturning(
        (_) => _profileResponse(tribeCode: 1),
        (options) => request = options,
      ),
    );

    final profile = await service.getMyProfile();

    expect(request!.method, 'GET');
    expect(request!.path, 'v1/profiles/me');
    expect(profile.userId, 'user-1');
    expect(profile.tribeCode, 1);
  });

  test('tribe selection posts the documented tribe code', () async {
    RequestOptions? request;
    final service = ProfileService(
      _dioReturning(
        (_) => _profileResponse(tribeCode: 1),
        (options) => request = options,
      ),
    );

    final profile = await service.updateTribe(1);

    expect(request!.method, 'POST');
    expect(request!.path, 'v1/profiles/me/tribe');
    expect(request!.data, {'tribeCode': 1});
    expect(profile.tribeCode, 1);
  });

  test('tribe list parses the documented items response', () async {
    RequestOptions? request;
    final service = ProfileService(
      _dioReturning(
        (_) => {
          'data': {
            'items': [_tribeJson()],
          },
        },
        (options) => request = options,
      ),
    );

    final tribes = await service.getTribes();

    expect(request!.method, 'GET');
    expect(request!.path, 'v1/tribes');
    expect(tribes.single.nameEn, 'Judah');
    expect(tribes.single.descriptionEn, 'A tribe description.');
  });

  test('tribe detail reads the documented code route', () async {
    RequestOptions? request;
    final service = ProfileService(
      _dioReturning(
        (_) => {
          'data': {'item': _tribeJson()},
        },
        (options) => request = options,
      ),
    );

    final tribe = await service.getTribe(1);

    expect(request!.method, 'GET');
    expect(request!.path, 'v1/tribes/1');
    expect(tribe.nameEn, 'Judah');
  });
}
