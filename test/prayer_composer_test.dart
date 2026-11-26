import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pray_like_incense/widgets/prayer_composer.dart';

void main() {
  testWidgets('phone composer offers voice and keeps a failed text draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PrayerDraft? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: PrayerComposer(
          hasTribe: false,
          onNavigate: (_) {},
          onPublish: (draft) async {
            submitted = draft;
            return false;
          },
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create voice post'));
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Chinese (Taiwan)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create text post'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Post'));
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
    expect(find.text('Title is required.'), findsOneWidget);
    expect(find.text('Content is required.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Prayer title');
    await tester.enterText(find.byType(TextFormField).last, 'Prayer content');
    await tester.ensureVisible(find.text('Post'));
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(submitted!.title, 'Prayer title');
    expect(submitted!.privacy, 'public');
    expect(submitted!.category, 'Personal & Family');
    expect(find.textContaining('Your draft has been kept'), findsOneWidget);
    expect(find.text('Prayer content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
