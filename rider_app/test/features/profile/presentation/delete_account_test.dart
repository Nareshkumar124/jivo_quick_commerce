import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/profile/presentation/delete_account_controller.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

/// Google Play launch: in-app account deletion (OTP confirmed, the same
/// endpoints as the customer app) and the policy links after login.
void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  Future<void> openDeleteFromProfile(WidgetTester tester) async {
    await openFromHome(tester, h, 'home-profile');
    await scrollTo(
      tester,
      byKey('profile-delete-account'),
      listKey: const Key('profile-list'),
    );
    await tester.tap(byKey('profile-delete-account'));
    await tester.pumpAndSettle();
  }

  testWidgets('profile: terms and privacy open the config URLs', (
    tester,
  ) async {
    await openFromHome(tester, h, 'home-profile');
    await scrollTo(
      tester,
      byKey('profile-privacy'),
      listKey: const Key('profile-list'),
    );

    await tester.tap(byKey('profile-terms'));
    await tester.tap(byKey('profile-privacy'));
    await tester.pumpAndSettle();

    expect(h.urls.opened, [
      Uri.parse('https://jivo.in/terms'),
      Uri.parse('https://jivo.in/privacy'),
    ]);
  });

  testWidgets('warns what is deleted, the 30-day grace and what the law '
      'keeps, with the public deletion page', (tester) async {
    await openDeleteFromProfile(tester);

    expect(find.textContaining('KYC documents'), findsOneWidget);
    expect(find.textContaining('30 days'), findsOneWidget);
    expect(find.textContaining('kept by law'), findsOneWidget);
    expect(h.deletion.calls, isEmpty, reason: 'nothing sent before a tap');

    await scrollTo(
      tester,
      byKey('delete-account-learn-more'),
      listKey: const Key('delete-account-explain'),
    );
    await tester.tap(byKey('delete-account-learn-more'));
    await tester.pumpAndSettle();
    expect(h.urls.opened, [accountDeletionInfoUrl]);
    expect(
      accountDeletionInfoUrl.toString(),
      'https://quick.jivo.in/legal/delete-account/',
    );
  });

  testWidgets('OTP to the rider\'s own phone; a wrong code shows the '
      'attempts left; the right one deletes and signs out', (tester) async {
    await openDeleteFromProfile(tester);

    await tester.tap(byKey('delete-account-send-otp'));
    await tester.pumpAndSettle();
    expect(h.deletion.calls, ['requestDeletionOtp $activeRiderPhone']);
    expect(textOf(tester, 'delete-account-otp-prompt'), contains('98111'));

    // Too short: checked before any call.
    await tester.enterText(byKey('delete-account-otp'), '12');
    await tester.tap(byKey('delete-account-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 6-digit OTP.'), findsOneWidget);
    expect(h.deletion.calls, hasLength(1));

    await tester.enterText(byKey('delete-account-otp'), '000000');
    await tester.tap(byKey('delete-account-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    expect(h.session.isSignedIn, isTrue);

    await tester.enterText(byKey('delete-account-otp'), '123456');
    await tester.tap(byKey('delete-account-confirm'));
    await tester.pumpAndSettle();

    expect(byKey('delete-account-done'), findsOneWidget);
    // 30 days after 2026-11-02 12:00 IST.
    expect(find.textContaining('Dec 2, 2026'), findsOneWidget);
    await tester.tap(byKey('delete-account-done-ok'));
    await tester.pumpAndSettle();

    expect(h.session.isSignedIn, isFalse);
    expect(h.cleaner.clears, greaterThanOrEqualTo(1));
    expect(byKey('login-phone'), findsOneWidget);
  });

  testWidgets('refused while online, like logout: nothing is sent', (
    tester,
  ) async {
    await openDeleteFromProfile(tester);
    h.location.running = true;

    await tester.tap(byKey('delete-account-send-otp'));
    await tester.pumpAndSettle();

    expect(
      find.text('Go offline before you delete your account.'),
      findsOneWidget,
    );
    expect(h.deletion.calls, isEmpty);
  });

  testWidgets('a server error is shown and the rider stays signed in', (
    tester,
  ) async {
    await openDeleteFromProfile(tester);
    await tester.tap(byKey('delete-account-send-otp'));
    await tester.pumpAndSettle();

    // No OTP pending any more on the server: OTP_EXPIRED.
    await h.deletion.deleteAccount(otp: '123456');
    await tester.enterText(byKey('delete-account-otp'), '123456');
    await tester.tap(byKey('delete-account-confirm'));
    await tester.pumpAndSettle();

    expect(find.text('This code has expired. Get a new code.'), findsOneWidget);
    expect(h.session.isSignedIn, isTrue);
  });

  testWidgets('a rider waiting for KYC reaches the policies and Delete '
      'account from the status screen menu', (tester) async {
    await h.signedInBefore(pendingPhone);
    await h.pump(tester);

    await tester.tap(byKey('account-menu'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('account-menu-privacy'));
    await tester.pumpAndSettle();
    expect(h.urls.opened, [Uri.parse('https://jivo.in/privacy')]);

    await tester.tap(byKey('account-menu'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('account-menu-delete'));
    await tester.pumpAndSettle();
    expect(byKey('delete-account-explain'), findsOneWidget);

    await tester.tap(byKey('delete-account-send-otp'));
    await tester.pumpAndSettle();
    expect(h.deletion.calls, ['requestDeletionOtp $pendingPhone']);
  });

  test('the fake follows the schema: OTP_INVALID with attempts, then '
      'OTP_EXPIRED', () async {
    final deletion = h.deletion;
    await deletion.requestDeletionOtp(activeRiderPhone);
    for (var left = 4; left >= 1; left--) {
      await expectLater(
        deletion.deleteAccount(otp: '999999'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.otpInvalid)
              .having((e) => e.details['attempts_remaining'], 'attempts', left),
        ),
      );
    }
    await expectLater(
      deletion.deleteAccount(otp: '999999'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.otpExpired),
      ),
    );
  });
}
