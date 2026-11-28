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
        findsNothing,
        reason: 'email sign-up works: no "register with phone" note',
      );
    });

    testWidgets('email only: email field, no "contact support to '
        'register" note (email sign-up works)', (tester) async {
      h.backend.loginMethods = const [LoginMethod.email];
      await h.pump(tester);
      expect(toggle(), findsNothing);
      expect(emailField(), findsOneWidget);
      expect(find.byKey(const Key('login-new-rider-support')), findsNothing);
      expect(find.byKey(const Key('login-support-call')), findsNothing);
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

    testWidgets('registered rider: email OTP signs in to home', (tester) async {
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

    testWidgets('a new email signs up: registration with a required '
        'Mobile number field', (tester) async {
      await h.pump(tester);
      await emailToOtp(tester, 'someone@example.com');
      await tester.enterText(codeField(), FakeAuthBackend.validOtp);
      await tester.pumpAndSettle();

      expect(h.session.isSignedIn, isTrue);
      expect(find.text('Become a Jivo rider'), findsOneWidget);
      expect(find.byKey(const Key('register-contact-phone')), findsOneWidget);
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
