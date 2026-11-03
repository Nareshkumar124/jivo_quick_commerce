import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  testWidgets('photo, name, phone, store, vehicle, KYC, rating; documents '
      'read-only', (tester) async {
    await openFromHome(tester, h, 'home-profile');

    expect(textOf(tester, 'profile-name'), 'Ravi Kumar');
    expect(textOf(tester, 'profile-phone'), '+91 98111 22231');
    expect(find.text('Jivo Sector 18, Noida'), findsOneWidget);
    expect(find.text('Motorbike · DL3CAB1234'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('4.8 ★'), findsOneWidget);
    expect(byKey('profile-photo'), findsOneWidget);

    await tester.tap(byKey('profile-documents'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(byKey('doc-PAN-status')).data, 'Approved');
    expect(find.text('XXXXXX234F'), findsOneWidget);
    expect(byKey('documents-continue'), findsNothing, reason: 'read-only');
    await tester.tap(byKey('doc-PAN'));
    await tester.pumpAndSettle();
    expect(byKey('capture-camera'), findsNothing);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    await pumpActiveHome(tester, h);
    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(byKey('home-profile'));
    await tester.pumpAndSettle();

    expect(byKey('profile-retry'), findsOneWidget);
    await tester.tap(byKey('profile-retry'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'profile-name'), 'Ravi Kumar');
  });
}
