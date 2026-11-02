import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

void main() {
  group('login', () {
    testWidgets('validates the +91 number before requesting an OTP', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);
      expect(find.text('Log in or sign up'), findsOneWidget);

      await loginToOtp(tester, '5876543210');

      expect(
        find.text('Enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
      expect(app.auth.otpRequests, isEmpty);
    });

    testWidgets('requests a login OTP and opens the OTP screen', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);

      await loginToOtp(tester, '9876543210');

      expect(app.auth.otpRequests.single.$1, '+919876543210');
      expect(find.text('Verify your number'), findsOneWidget);
      expect(
        find.text('Enter the 6-digit OTP sent to +919876543210'),
        findsOneWidget,
      );
    });

    testWidgets('shows the lockout wait for OTP_RATE_LIMITED', (tester) async {
      final app = TestApp();
      app.auth.requestError = const ApiError(
        code: ApiErrorCode.otpRateLimited,
        statusCode: 429,
        details: {'retry_after_seconds': 540},
      );
      await app.pump(tester);

      await loginToOtp(tester, '9876543210');

      expect(
        find.text('Too many attempts. Please try again in 9 minutes.'),
        findsOneWidget,
      );
      expect(find.text('Log in or sign up'), findsOneWidget);
    });

    testWidgets('consent links open the policy URLs', (tester) async {
      final app = TestApp();
      await app.pump(tester);

      await tester.tap(find.text('Terms of Service'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();

      expect(app.urls.opened.map((u) => u.path), ['/terms', '/privacy']);
    });

    testWidgets('meets tap-target and label guidelines', (tester) async {
      final semantics = tester.ensureSemantics();
      await TestApp().pump(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('explains an expired session', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);

      await app.session.signOut(reason: SignOutReason.sessionExpired);
      await tester.pumpAndSettle();

      expect(
        find.text('Your session has expired. Please log in again.'),
        findsOneWidget,
      );
    });
  });

  group('OTP', () {
    testWidgets('a wrong OTP shows the attempts left', (tester) async {
      final app = TestApp();
      await app.pump(tester);
      await loginToOtp(tester, '9876543210');

      await tester.enterText(find.byKey(const Key('otp-field')), '000000');
      await tester.pumpAndSettle();

      expect(
        find.text('That OTP is incorrect. 4 attempts left.'),
        findsOneWidget,
      );
      expect(app.session.isSignedIn, isFalse);
    });

    testWidgets('OTP_EXPIRED asks for a new OTP', (tester) async {
      final app = TestApp();
      app.auth.verifyError = const ApiError(
        code: ApiErrorCode.otpExpired,
        statusCode: 400,
      );
      await app.pump(tester);
      await loginToOtp(tester, '9876543210');

      await tester.enterText(find.byKey(const Key('otp-field')), '123456');
      await tester.pumpAndSettle();

      expect(
        find.text('That OTP has expired. Please request a new one.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a new user signs in with the terms version and completes the profile',
      (tester) async {
        final app = TestApp();
        await app.pump(tester);
        await loginToOtp(tester, '9876543210');

        await tester.enterText(
          find.byKey(const Key('otp-field')),
          FakeAuthRepository.validOtp,
        );
        await tester.pumpAndSettle();

        expect(app.session.isSignedIn, isTrue);
        expect(app.auth.verifiedTermsVersions, ['2026-11-01']);
        expect(find.text('Tell us about you'), findsOneWidget);
      },
    );

    testWidgets(
      'an existing user goes home; a cancelled deletion is announced',
      (tester) async {
        final app = TestApp();
        app.auth.deletionCancelled = true;
        await app.pump(tester);
        await loginToOtp(tester, '9000000001');

        await tester.enterText(
          find.byKey(const Key('otp-field')),
          FakeAuthRepository.validOtp,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('home-screen')), findsOneWidget);
        expect(
          find.text(
            'Welcome back! Your account deletion request has been cancelled.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('resend unlocks after the countdown', (tester) async {
      final app = TestApp();
      await app.pump(tester);
      await loginToOtp(tester, '9876543210');
      expect(find.text('Resend OTP in 30s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(app.auth.otpRequests, hasLength(2));
      expect(find.text('A new OTP has been sent.'), findsOneWidget);
      expect(find.text('Resend OTP in 30s'), findsOneWidget);
    });

    testWidgets('an autofilled OTP is verified without typing', (tester) async {
      final app = TestApp(autofillCode: FakeAuthRepository.validOtp);
      await app.pump(tester);

      await loginToOtp(tester, '9000000001');

      expect(app.autofill.listens, 1);
      expect(app.session.isSignedIn, isTrue);
      expect(find.byKey(const Key('home-screen')), findsOneWidget);
    });

    testWidgets('a deactivated account gets a clear message', (tester) async {
      final app = TestApp();
      app.auth.verifyError = const ApiError(
        code: ApiErrorCode.permissionDenied,
        statusCode: 403,
      );
      await app.pump(tester);
      await loginToOtp(tester, '9876543210');

      await tester.enterText(find.byKey(const Key('otp-field')), '123456');
      await tester.pumpAndSettle();

      expect(
        find.text('This account is deactivated. Please contact support.'),
        findsOneWidget,
      );
    });
  });
}
