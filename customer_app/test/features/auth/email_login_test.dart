import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/domain/auth_models.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/profile/domain/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../checkout/checkout_flow_test.dart'
    show appWithCart, openCheckout, placeButton;

const emailOnlyUser = UserProfile(
  id: 3,
  phone: '',
  name: 'Asha Verma',
  email: 'asha@example.com',
  isProfileComplete: true,
  hasPhone: false,
  emailVerified: true,
);

Future<void> loginByEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.tap(find.text('Get OTP'));
  await tester.pumpAndSettle();
}

Future<void> openAccount(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeFormatting);

  group('login methods', () {
    testWidgets('phone only (the default): no choice, the phone field', (
      tester,
    ) async {
      final app = TestApp();
      await app.pump(tester);

      expect(app.auth.methodsCalls, 1, reason: 'loaded at start-up');
      expect(find.byKey(const Key('login-method')), findsNothing);
      expect(find.byKey(const Key('login-phone')), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);
    });

    testWidgets('a failed methods call falls back to phone', (tester) async {
      final app = TestApp();
      app.auth.methodsError = const ApiError(code: ApiErrorCode.network);
      await app.pump(tester);

      expect(find.byKey(const Key('login-phone')), findsOneWidget);
      expect(find.byKey(const Key('login-method')), findsNothing);
    });

    testWidgets('email only: the email field, no choice', (tester) async {
      final app = TestApp();
      app.auth.methods = const [LoginMethod.email];
      await app.pump(tester);

      expect(find.byKey(const Key('login-method')), findsNothing);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(
        find.text('Enter your email address to get an OTP.'),
        findsOneWidget,
      );
    });

    testWidgets('both: Email by default, a Phone / Email choice switches', (
      tester,
    ) async {
      final app = TestApp();
      app.auth.methods = const [LoginMethod.phone, LoginMethod.email];
      await app.pump(tester);

      expect(find.byKey(const Key('login-method')), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('login-phone')), findsNothing);

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-phone')), findsOneWidget);
      expect(find.byKey(const Key('login-email')), findsNothing);

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.byKey(const Key('login-phone')), findsNothing);
    });

    testWidgets('LOGIN_METHOD_DISABLED switches to the methods still on', (
      tester,
    ) async {
      final app = TestApp();
      app.auth.methods = const [LoginMethod.phone, LoginMethod.email];
      await app.pump(tester);
      app.auth.requestError = const ApiError(
        code: ApiErrorCode.loginMethodDisabled,
        statusCode: 403,
        details: {
          'app': 'customer',
          'method': 'phone',
          'methods': ['email'],
        },
      );
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      await loginToOtp(tester, '9876543210');

      expect(find.byKey(const Key('login-method')), findsNothing);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(
        find.text(
          'This sign-in option is turned off right now. '
          'Please use the other option.',
        ),
        findsOneWidget,
      );
    });
  });

  group('email OTP', () {
    testWidgets('validates the email before requesting', (tester) async {
      final app = TestApp();
      app.auth.methods = const [LoginMethod.email];
      await app.pump(tester);

      await loginByEmail(tester, 'asha@');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(app.auth.emailOtpRequests, isEmpty);
    });

    testWidgets(
      'a new email user verifies, signs in with the terms version and '
      'completes the profile with the email locked',
      (tester) async {
        final app = TestApp();
        app.auth.methods = const [LoginMethod.email];
        await app.pump(tester);

        await loginByEmail(tester, 'Asha@Example.com');
        expect(app.auth.emailOtpRequests.single, (
          'asha@example.com',
          OtpPurpose.login,
        ));
        expect(find.text('Verify your email'), findsOneWidget);
        expect(
          find.text('Enter the 6-digit OTP sent to asha@example.com'),
          findsOneWidget,
        );
        expect(find.text('Change email'), findsOneWidget);
        expect(app.autofill.listens, 0, reason: 'no SMS autofill for email');

        await tester.enterText(
          find.byKey(const Key('otp-field')),
          FakeAuthRepository.validOtp,
        );
        await tester.pumpAndSettle();

        expect(app.session.isSignedIn, isTrue);
        expect(app.auth.verifiedTermsVersions, ['2026-11-01']);
        expect(find.text('Tell us about you'), findsOneWidget);
        final email = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('profile-email')),
            matching: find.byType(TextField),
          ),
        );
        expect(email.enabled, isFalse);
        expect(
          find.text("You log in with this email, so it can't be changed here."),
          findsOneWidget,
        );
      },
    );

    testWidgets('a wrong code shows the attempts left', (tester) async {
      final app = TestApp();
      app.auth.methods = const [LoginMethod.email];
      await app.pump(tester);
      await loginByEmail(tester, 'asha@example.com');

      await tester.enterText(find.byKey(const Key('otp-field')), '000000');
      await tester.pumpAndSettle();

      expect(find.text('That OTP is incorrect. 4 attempts left.'), findsOne);
      expect(app.session.isSignedIn, isFalse);
    });
  });

  group('email-only account', () {
    testWidgets('account shows the verified email and adds a phone by OTP', (
      tester,
    ) async {
      final app = TestApp(tokens: signedInTokens);
      app.profile.profile = emailOnlyUser;
      await app.pump(tester);
      await openAccount(tester);

      expect(find.text('No mobile number added'), findsOneWidget);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-add-phone')));
      await tester.pumpAndSettle();
      expect(find.text('Add mobile number'), findsWidgets);

      await tester.enterText(
        find.byKey(const Key('contact-value')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('contact-send')));
      await tester.pumpAndSettle();
      expect(app.profile.phoneOtpRequests.single, '+919876543210');

      await tester.enterText(find.byKey(const Key('contact-otp')), '123456');
      await tester.pumpAndSettle();

      expect(find.text('Mobile number added.'), findsOneWidget);
      expect(find.text('No mobile number added'), findsNothing);
      expect(find.text('+91 •••••••210'), findsOneWidget);
      expect(find.byKey(const Key('account-add-phone')), findsNothing);
    });

    testWidgets('PHONE_IN_USE is explained on the OTP step', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.profile.profile = emailOnlyUser;
      await app.pump(tester);
      await openAccount(tester);
      await tester.tap(find.byKey(const Key('account-add-phone')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('contact-value')),
        '9876543210',
      );
      await tester.tap(find.byKey(const Key('contact-send')));
      await tester.pumpAndSettle();

      app.profile.contactError = const ApiError(
        code: ApiErrorCode.phoneInUse,
        statusCode: 409,
      );
      await tester.enterText(find.byKey(const Key('contact-otp')), '123456');
      await tester.pumpAndSettle();

      expect(
        find.text('This phone number is already used by another account.'),
        findsOneWidget,
      );
    });

    testWidgets('a phone user adds and verifies an email', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);
      await openAccount(tester);

      await tester.tap(find.byKey(const Key('account-add-email')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('contact-value')),
        'asha@example.com',
      );
      await tester.tap(find.byKey(const Key('contact-send')));
      await tester.pumpAndSettle();
      expect(app.profile.emailOtpRequests.single, 'asha@example.com');

      await tester.enterText(find.byKey(const Key('contact-otp')), '123456');
      await tester.pumpAndSettle();

      expect(find.text('Email verified.'), findsOneWidget);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.byKey(const Key('account-add-email')), findsNothing);
    });

    testWidgets('delete account sends the OTP by email', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.profile.profile = emailOnlyUser;
      await app.pump(tester);
      await openAccount(tester);
      await tester.scrollUntilVisible(find.text('Delete account'), 100);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send OTP to confirm'));
      await tester.pumpAndSettle();

      expect(app.auth.otpRequests, isEmpty);
      expect(app.auth.emailOtpRequests.single, (
        'asha@example.com',
        OtpPurpose.deleteAccount,
      ));
      expect(find.textContaining('asha@example.com'), findsOneWidget);
    });

    testWidgets('delete account uses the verified email even with a phone', (
      tester,
    ) async {
      final app = TestApp(tokens: signedInTokens);
      app.profile.profile = const UserProfile(
        id: 3,
        phone: '+919876543210',
        name: 'Asha Verma',
        email: 'asha@example.com',
        isProfileComplete: true,
        emailVerified: true,
      );
      await app.pump(tester);
      await openAccount(tester);
      await tester.scrollUntilVisible(find.text('Delete account'), 100);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send OTP to confirm'));
      await tester.pumpAndSettle();

      expect(app.auth.otpRequests, isEmpty);
      expect(app.auth.emailOtpRequests.single, (
        'asha@example.com',
        OtpPurpose.deleteAccount,
      ));
    });

    testWidgets(
      'checkout asks for a contact phone on the address before ordering',
      (tester) async {
        const location = DeliveryLocation(
          point: FakeServiceabilityRepository.storeLocation,
          title: 'Home',
          subtitle: 'Flat 4B, MG Road, New Delhi',
          addressId: 100,
        );
        final app = await appWithCart(location: location);
        app.profile.profile = emailOnlyUser;
        await app.addresses.create(
          const AddressInput(
            label: AddressLabel.home,
            house: 'Flat 4B',
            buildingStreet: 'MG Road',
            city: 'New Delhi',
            state: 'Delhi',
            pincode: '110001',
            lat: 28.6,
            lng: 77.2,
          ),
        );
        await openCheckout(tester, app);

        expect(
          find.text(
            'Add a mobile number to this address so the delivery partner '
            'can call you.',
          ),
          findsOneWidget,
        );
        expect(placeButton(tester).onPressed, isNull);

        await tester.tap(find.byKey(const Key('checkout-add-contact-phone')));
        await tester.pumpAndSettle();
        expect(find.text("Receiver's mobile number"), findsOneWidget);
      },
    );
  });
}
