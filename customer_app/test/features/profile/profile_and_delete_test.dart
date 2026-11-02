import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/domain/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

Future<void> signInAsNewUser(TestApp app, WidgetTester tester) async {
  await app.pump(tester);
  await loginToOtp(tester, '9876543210');
  await tester.enterText(
    find.byKey(const Key('otp-field')),
    FakeAuthRepository.validOtp,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('complete profile', () {
    testWidgets('requires a name and checks the email format', (tester) async {
      final app = TestApp();
      await signInAsNewUser(app, tester);

      await tester.enterText(find.byKey(const Key('profile-email')), 'asha@');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows the generic message for a rejected email', (
      tester,
    ) async {
      final app = TestApp();
      app.profile.updateError = const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 400,
        details: {
          'email': ["This email can't be used."],
        },
      );
      await signInAsNewUser(app, tester);

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Asha Verma',
      );
      await tester.enterText(
        find.byKey(const Key('profile-email')),
        'taken@example.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text("This email can't be used."), findsOneWidget);
      expect(find.text('Tell us about you'), findsOneWidget);
    });

    testWidgets('saving the name finishes sign-up', (tester) async {
      final app = TestApp();
      await signInAsNewUser(app, tester);

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Asha Verma',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(app.profile.profile.name, 'Asha Verma');
      expect(find.text('Hi, Asha Verma!'), findsOneWidget);
    });
  });

  group('delete account', () {
    Future<void> openDelete(TestApp app, WidgetTester tester) async {
      await app.pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Delete account'), 100);
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
    }

    testWidgets('explains the grace period, confirms by OTP, then signs out', (
      tester,
    ) async {
      final app = TestApp(tokens: signedInTokens);
      await openDelete(app, tester);
      expect(
        find.textContaining('30 days to change your mind'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'Moving abroad');
      await tester.tap(find.text('Send OTP to confirm'));
      await tester.pumpAndSettle();
      expect(app.auth.otpRequests.single, (
        '+919000000001',
        OtpPurpose.deleteAccount,
      ));

      await tester.enterText(find.byKey(const Key('delete-otp')), '123456');
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(app.profile.deletions.single, ('123456', 'Moving abroad'));
      expect(find.text('Account deleted'), findsOneWidget);
      expect(find.textContaining('2 Dec 2026'), findsOneWidget);
      expect(
        app.session.isSignedIn,
        isTrue,
        reason: 'signs out only after the dialog',
      );

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(app.session.isSignedIn, isFalse);
      expect(find.text('Log in or sign up'), findsOneWidget);
    });

    testWidgets('a wrong OTP keeps the user on the screen', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      await openDelete(app, tester);
      await tester.tap(find.text('Send OTP to confirm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('delete-otp')), '000000');
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(
        find.text('That OTP is incorrect. 4 attempts left.'),
        findsOneWidget,
      );
      expect(app.session.isSignedIn, isTrue);
    });

    testWidgets('staff accounts get a clear refusal', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.profile.deleteError = const ApiError(
        code: ApiErrorCode.permissionDenied,
        statusCode: 403,
      );
      await openDelete(app, tester);
      await tester.tap(find.text('Send OTP to confirm'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-otp')), '123456');
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "This account can't be deleted from the app. Please contact support.",
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('logout revokes the refresh token and returns to login', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Log out'), 100);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(app.auth.loggedOutTokens, ['r1']);
    expect(app.session.isSignedIn, isFalse);
    expect(await app.store.read(), isNull);
    expect(find.text('Log in or sign up'), findsOneWidget);
  });
}
