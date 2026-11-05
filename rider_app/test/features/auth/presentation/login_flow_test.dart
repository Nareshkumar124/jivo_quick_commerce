import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/data/fake_auth_backend.dart';

import '../../../helpers/rider_app_harness.dart';

Finder phoneField() => find.byKey(const Key('login-phone'));
Finder getOtp() => find.byKey(const Key('login-get-otp'));
Finder codeField() => find.byKey(const Key('otp-code'));

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// Login screen → OTP screen for [digits]. Leaves the countdown running.
  Future<void> toOtp(WidgetTester tester, String digits) async {
    await h.pump(tester);
    await tester.enterText(phoneField(), digits);
    await tester.tap(getOtp());
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  group('phone login', () {
    testWidgets('validates the number before calling the API', (tester) async {
      await h.pump(tester);

      await tester.tap(getOtp());
      await tester.pump();
      expect(find.text('Enter your mobile number.'), findsOneWidget);

      await tester.enterText(phoneField(), '98765');
      await tester.tap(getOtp());
      await tester.pump();
      expect(find.text('Enter all 10 digits.'), findsOneWidget);

      await tester.enterText(phoneField(), '5876543210');
      await tester.tap(getOtp());
      await tester.pump();
      expect(
        find.text(
          'Enter a valid Indian mobile number starting with 6, 7, 8 or 9.',
        ),
        findsOneWidget,
      );

      expect(h.backend.calls, isEmpty);
      expect(
        tester.getSize(getOtp()).height,
        greaterThanOrEqualTo(56),
        reason: 'rider primary actions are at least 56 dp',
      );
    });

    testWidgets('only digits, at most 10, behind a fixed +91', (tester) async {
      await h.pump(tester);
      await tester.enterText(phoneField(), '98a76-54321099');
      await tester.pump();

      final field = tester.widget<TextField>(phoneField());
      expect(field.controller!.text, '9876543210');
      expect(field.decoration!.prefixText, '+91 ');
    });

    testWidgets('a valid number requests an OTP with +91 and opens the OTP '
        'step', (tester) async {
      await toOtp(tester, '9811122231');

      expect(h.backend.calls, ['requestOtp +919811122231']);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(
        find.text('We sent a 6-digit code to +91 98111 22231.'),
        findsOneWidget,
      );
    });

    testWidgets('consent links open the policy URLs from config/app', (
      tester,
    ) async {
      await h.pump(tester);

      expect(find.byKey(const Key('login-consent')), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring('Terms of Use'));
      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));

      expect(h.urls.opened, [
        Uri.parse('https://jivo.in/terms'),
        Uri.parse('https://jivo.in/privacy'),
      ]);
    });

    testWidgets('OTP_RATE_LIMITED shows how long to wait', (tester) async {
      await h.pump(tester);
      await tester.enterText(phoneField(), '9999999999');
      await tester.tap(getOtp());
      await tester.pumpAndSettle();

      expect(
        find.text('Too many attempts. Try again in 9 minutes.'),
        findsOneWidget,
      );
      expect(find.text('Enter the code'), findsNothing);
    });

    testWidgets('after an expired session, asks to log in again', (
      tester,
    ) async {
      await h.signedInBefore('+919811122231');
      await h.session.restore();
      await h.session.signOut(reason: SignOutReason.sessionExpired);
      await h.pump(tester);

      expect(
        find.text('Your session has ended. Please log in again.'),
        findsOneWidget,
      );
    });
  });

  group('OTP verify', () {
    testWidgets('resend countdown starts from resend_after_seconds', (
      tester,
    ) async {
      await toOtp(tester, '9811122231');

      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.byKey(const Key('otp-resend')), findsNothing);

      await pumpFor(tester, const Duration(seconds: 30));
      expect(find.byKey(const Key('otp-resend')), findsOneWidget);

      await tester.tap(find.byKey(const Key('otp-resend')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(
        h.backend.calls.where((c) => c.startsWith('requestOtp')),
        hasLength(2),
      );
      expect(find.text('Resend code in 30 s'), findsOneWidget);
    });

    testWidgets('OTP_RATE_LIMITED on resend restarts the countdown from '
        'retry_after_seconds', (tester) async {
      await toOtp(tester, '9811122231');
      await pumpFor(tester, const Duration(seconds: 30));

      h.backend.rateLimitRequests = true;
      await tester.tap(find.byKey(const Key('otp-resend')));
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(
        find.text('Too many attempts. Try again in 9 minutes.'),
        findsOneWidget,
      );
      expect(find.text('Resend code in 540 s'), findsOneWidget);
    });

    testWidgets('a wrong code shows the attempts left and clears the field', (
      tester,
    ) async {
      await toOtp(tester, '9811122231');

      await tester.enterText(codeField(), '000000');
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
      expect(tester.widget<TextField>(codeField()).controller!.text, isEmpty);
      expect(h.backend.calls.last, contains('terms=2026-11-01'));
    });

    testWidgets('OTP_EXPIRED after the last attempt: Get a new code becomes '
        'the primary action', (tester) async {
      await toOtp(tester, '9811122231');

      for (var i = 0; i < FakeAuthBackend.maxAttempts; i++) {
        await tester.enterText(codeField(), '000000');
        await pumpFor(tester, const Duration(milliseconds: 200));
      }

      expect(
        find.text('This code has expired. Get a new code.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('otp-verify')), findsNothing);

      await tester.tap(find.byKey(const Key('otp-get-new-code')));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const Key('otp-verify')), findsOneWidget);
      expect(find.text('This code has expired. Get a new code.'), findsNothing);
    });

    testWidgets('Change number goes back to the phone step', (tester) async {
      await toOtp(tester, '9811122231');

      await tester.tap(find.byKey(const Key('otp-change-number')));
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(find.text('Log in to Jivo Rider'), findsOneWidget);
    });
  });

  group('routing after verify by rider_status', () {
    Future<void> verify(WidgetTester tester, String digits) async {
      await toOtp(tester, digits);
      await tester.enterText(codeField(), FakeAuthBackend.validOtp);
      await tester.pumpAndSettle();
    }

    testWidgets('ACTIVE: home, with the session stored', (tester) async {
      await verify(tester, '9811122231');

      expect(find.byKey(const Key('home-flavor')), findsOneWidget);
      expect(h.session.isSignedIn, isTrue);
      expect(await h.tokenStore.read(), isNotNull);
    });

    testWidgets('NONE: registration form', (tester) async {
      await verify(tester, '9811122235');
      expect(find.text('Become a Jivo rider'), findsOneWidget);
    });

    testWidgets('PENDING_KYC: approval status screen', (tester) async {
      await verify(tester, '9811122232');
      expect(find.text('Documents under review'), findsOneWidget);
    });

    testWidgets('SUSPENDED offers a call to support', (tester) async {
      await verify(tester, '9811122234');
      expect(find.text('Account suspended'), findsOneWidget);

      await tester.tap(find.byKey(const Key('call-support')));
      expect(h.urls.opened.single, Uri(scheme: 'tel', path: '+911800123456'));
    });
  });

  group('session restore and logout', () {
    testWidgets('app start with stored tokens: GET /me/ decides the screen', (
      tester,
    ) async {
      await h.signedInBefore('+919811122233'); // REJECTED
      await h.pump(tester);

      expect(h.backend.calls, ['fetchMe']);
      expect(find.text('Documents not approved'), findsOneWidget);
    });

    testWidgets('logout from home goes back to login', (tester) async {
      await h.signedInBefore('+919811122231');
      await h.pump(tester);
      expect(find.byKey(const Key('home-flavor')), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(find.text('Log in to Jivo Rider'), findsOneWidget);
      expect(h.cleaner.clears, 1);
      expect(
        find.text('Your session has ended. Please log in again.'),
        findsNothing,
      );
    });

    testWidgets('logout is blocked while online', (tester) async {
      await h.signedInBefore('+919811122235'); // NONE: registration form
      await h.pump(tester);
      h.location.running = true;

      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(find.text('Go offline before logging out.'), findsOneWidget);
      expect(find.text('Become a Jivo rider'), findsOneWidget);
      expect(h.session.isSignedIn, isTrue);
    });

    testWidgets('dev tools are reachable in dev only', (tester) async {
      await h.signedInBefore('+919811122231');
      await h.pump(tester);
      expect(find.byKey(const Key('dev-tools')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('dev-tools')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dev-tools')));
      await tester.pumpAndSettle();
      expect(find.text('Location spike (dev)'), findsOneWidget);
    });

    testWidgets('prod flavor: no dev tools', (tester) async {
      h = RiderTestHarness(flavor: Flavor.prod);
      await h.signedInBefore('+919811122231');
      await h.pump(tester);

      expect(find.text('Build: prod'), findsOneWidget);
      expect(find.byKey(const Key('dev-tools')), findsNothing);
    });
  });
}
