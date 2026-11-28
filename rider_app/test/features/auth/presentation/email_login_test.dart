import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/data/fake_auth_backend.dart';
import 'package:rider_app/features/auth/domain/login_method.dart';

import '../../../helpers/rider_app_harness.dart';

Finder phoneField() => find.byKey(const Key('login-phone'));
Finder emailField() => find.byKey(const Key('login-email'));
Finder getOtp() => find.byKey(const Key('login-get-otp'));
Finder codeField() => find.byKey(const Key('otp-code'));
Finder toggle() => find.byKey(const Key('login-method-toggle'));

const notRegistered =
    "This email isn't registered as a rider. Contact Jivo support at "
    'info@jivo.in or +91 8595 349 565';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  Future<void> emailToOtp(WidgetTester tester, String email) async {
    await tester.enterText(emailField(), email);
    await tester.tap(getOtp());
    await pumpFor(tester, const Duration(milliseconds: 600));
  }

  group('login methods (GET /auth/methods/)', () {
    testWidgets('phone only: no toggle, phone field', (tester) async {
      await h.pump(tester);
      expect(toggle(), findsNothing);
      expect(phoneField(), findsOneWidget);
      expect(emailField(), findsNothing);
    });

    testWidgets('both: Phone/Email toggle, phone first', (tester) async {
      h.backend.loginMethods = const [LoginMethod.phone, LoginMethod.email];
      await h.pump(tester);
      expect(toggle(), findsOneWidget);
      expect(phoneField(), findsOneWidget);

      await tester.tap(find.byKey(const Key('login-method-email')));
      await tester.pumpAndSettle();
      expect(emailField(), findsOneWidget);
      expect(phoneField(), findsNothing);
      expect(
        find.byKey(const Key('login-new-rider-phone')),
        findsOneWidget,
        reason: 'new riders are pointed to phone registration',
      );
    });

    testWidgets('email only: email field and the support note for new '
        'riders (no dead end)', (tester) async {
      h.backend.loginMethods = const [LoginMethod.email];
      await h.pump(tester);
      expect(toggle(), findsNothing);
      expect(emailField(), findsOneWidget);
      expect(find.byKey(const Key('login-new-rider-support')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('login-support-call')).first,
      );
      await tester.tap(find.byKey(const Key('login-support-call')).first);
      await tester.pump();
      expect(h.urls.opened.last.toString(), 'tel:+918595349565');
    });
  });

  group('email login', () {
    setUp(() {
      h.backend.loginMethods = const [LoginMethod.email];
    });

    testWidgets('validates the email before calling the API', (tester) async {
      await h.pump(tester);
      await tester.tap(getOtp());
      await tester.pump();
      expect(find.text('Enter your email.'), findsOneWidget);

      await tester.enterText(emailField(), 'ravi@');
      await tester.tap(getOtp());
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(h.backend.calls, isEmpty);
    });

    testWidgets('registered rider: email OTP signs in to home', (
      tester,
    ) async {
      await h.pump(tester);
      await emailToOtp(tester, FakeAuthBackend.registeredEmail);

      expect(h.backend.calls, contains('requestEmailOtp ravi@example.com'));
      expect(
        find.textContaining('We emailed a 6-digit code to ravi@example.com'),
        findsOneWidget,
      );
      expect(find.text('Change email'), findsOneWidget);

      await tester.enterText(codeField(), FakeAuthBackend.validOtp);
      await tester.pumpAndSettle();

      expect(
        h.backend.calls.where((c) => c.startsWith('verifyEmailOtp')),
        hasLength(1),
      );
      expect(find.byKey(const Key('home-flavor')), findsOneWidget);
      expect(h.session.isSignedIn, isTrue);
    });

    testWidgets('wrong code: attempts left, same as phone', (tester) async {
      await h.pump(tester);
      await emailToOtp(tester, FakeAuthBackend.registeredEmail);
      await tester.enterText(codeField(), '000000');
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Wrong code. 4 attempts left.'), findsOneWidget);
    });

    testWidgets('EMAIL_NOT_REGISTERED: support message and contacts', (
      tester,
    ) async {
      await h.pump(tester);
      await emailToOtp(tester, 'someone@example.com');
      await tester.enterText(codeField(), FakeAuthBackend.validOtp);
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(find.text(notRegistered), findsOneWidget);
      expect(h.session.isSignedIn, isFalse);
      await tester.tap(find.byKey(const Key('login-support-email')));
      await tester.pump();
      expect(h.urls.opened.last.toString(), 'mailto:info@jivo.in');
    });

    testWidgets('LOGIN_METHOD_DISABLED: message, then the screen offers '
        'the method that is on', (tester) async {
      await h.pump(tester);
      // The admin switches email off after the screen loaded.
      h.backend.loginMethods = const [LoginMethod.phone];
      await tester.enterText(emailField(), FakeAuthBackend.registeredEmail);
      await tester.tap(getOtp());
      await pumpFor(tester, const Duration(milliseconds: 600));

      expect(
        find.text(
          'This way of logging in is switched off. '
          'Please use the other option shown.',
        ),
        findsOneWidget,
      );
      expect(phoneField(), findsOneWidget);
    });
  });
}
