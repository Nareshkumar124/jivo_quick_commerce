import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/domain/rider_account.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';
import 'package:rider_app/features/onboarding/presentation/registration_screen.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

const form = Key('register-form');
Finder byKey(String key) => find.byKey(Key(key));

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// A signed-in user without a rider profile (`NONE`).
  Future<void> open(WidgetTester tester) async {
    await h.signedInBefore(nonePhone);
    await h.pump(tester);
    expect(find.byType(RegistrationScreen), findsOneWidget);
  }

  Future<void> show(WidgetTester tester, String key) =>
      scrollTo(tester, byKey(key), listKey: form);

  Future<void> chooseDob(WidgetTester tester, String year, String day) async {
    await show(tester, 'register-dob');
    await tester.tap(byKey('register-dob'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(year));
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseStore(WidgetTester tester, String label) async {
    await show(tester, 'register-store');
    await tester.tap(byKey('register-store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseVehicle(WidgetTester tester, VehicleType type) async {
    final key = 'register-vehicle-${type.wireValue}';
    await show(tester, key);
    await tester.tap(byKey(key));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(byKey('register-submit'));
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(WidgetTester tester) async {
    await tester.enterText(byKey('register-name'), 'Ravi Kumar');
    await chooseDob(tester, '2005', '15');
    await show(tester, 'register-emergency-name');
    await tester.enterText(byKey('register-emergency-name'), 'Sunita Kumar');
    await show(tester, 'register-emergency-phone');
    await tester.enterText(byKey('register-emergency-phone'), '9876500001');
    await chooseStore(tester, 'Jivo Indirapuram, Ghaziabad');
  }

  testWidgets('NONE opens the form: title, stores loaded, logout, 56 dp '
      'Continue', (tester) async {
    await open(tester);

    expect(find.text('Become a Jivo rider'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(byKey('logout'), findsOneWidget);
    expect(h.onboarding.calls, ['fetchStores']);
    expect(
      tester.getSize(byKey('register-submit')).height,
      greaterThanOrEqualTo(56),
    );
    // The account name from /me/ is prefilled.
    expect(
      tester.widget<TextField>(byKey('register-name')).controller!.text,
      'Ravi Kumar',
    );
  });

  testWidgets('an empty form shows every error and calls nothing', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(byKey('register-name'), '');
    await submit(tester);

    expect(find.text('This is required.'), findsWidgets);
    expect(h.onboarding.calls, ['fetchStores']);
    await show(tester, 'register-vehicle-BICYCLE');
    expect(find.text('This is required.'), findsWidgets);
  });

  testWidgets('vehicle number: only for motorbike and scooter, and required '
      'there', (tester) async {
    await open(tester);
    await fillValidForm(tester);
    await chooseVehicle(tester, VehicleType.bicycle);
    expect(byKey('register-vehicle-number'), findsNothing);
    await chooseVehicle(tester, VehicleType.eBike);
    expect(byKey('register-vehicle-number'), findsNothing);

    await chooseVehicle(tester, VehicleType.motorbike);
    await show(tester, 'register-vehicle-number');
    expect(byKey('register-vehicle-number'), findsOneWidget);

    await submit(tester);
    await show(tester, 'register-vehicle-number');
    expect(find.text('This is required.'), findsOneWidget);

    await tester.enterText(byKey('register-vehicle-number'), 'DL3');
    await submit(tester);
    await show(tester, 'register-vehicle-number');
    expect(
      find.text(
        'Enter the vehicle number as on the number plate, like DL 3C AB 1234.',
      ),
      findsOneWidget,
    );
    expect(h.onboarding.calls, isNot(contains('register')));
  });

  testWidgets('the emergency contact cannot be the rider\'s own number', (
    tester,
  ) async {
    await open(tester);
    await fillValidForm(tester);
    await chooseVehicle(tester, VehicleType.bicycle);
    await show(tester, 'register-emergency-phone');
    await tester.enterText(byKey('register-emergency-phone'), '9811122235');
    await submit(tester);
    await show(tester, 'register-emergency-phone');

    expect(
      find.text("Enter someone else's number, not your own."),
      findsOneWidget,
    );
    expect(h.onboarding.calls, isNot(contains('register')));
  });

  testWidgets('the date picker stops at the 18th birthday', (tester) async {
    await open(tester);
    await show(tester, 'register-dob');
    await tester.tap(byKey('register-dob'));
    await tester.pumpAndSettle();

    // Today is 2 Nov 2026 (IST): 2008 is the last year offered, 2009 is not.
    expect(find.text('2008'), findsOneWidget);
    expect(find.text('2009'), findsNothing);
  });

  testWidgets('a valid motorbike registration: POST /rider/register/, then '
      'the status screen with the next step', (tester) async {
    await open(tester);
    await fillValidForm(tester);
    await chooseVehicle(tester, VehicleType.motorbike);
    await show(tester, 'register-vehicle-number');
    await tester.enterText(byKey('register-vehicle-number'), 'dl 3c ab 1234');
    expect(
      tester
          .widget<TextField>(byKey('register-vehicle-number'))
          .controller!
          .text,
      'DL 3C AB 1234',
      reason: 'upper-cased while typing',
    );
    await submit(tester);

    expect(h.onboarding.calls, ['fetchStores', 'register', 'fetchProfile']);
    final profile = h.onboarding.profileOf(nonePhone)!;
    expect(profile.vehicleNumber, 'DL3CAB1234');
    expect(profile.preferredStore.id, 2);
    expect(profile.dateOfBirth, DateTime.utc(2005, 11, 15));
    expect(profile.emergencyContactPhone, '+919876500001');

    expect(find.text('Finish your application'), findsOneWidget);
    expect(find.text('0 of 6 uploaded'), findsOneWidget);
    expect(find.text('Upload documents'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Finish your application')),
    );
    final account =
        container.read(riderAccountControllerProvider) as AccountLoaded;
    expect(account.riderStatus, RiderStatusEnum.PENDING_KYC);
  });

  testWidgets('a server error is shown above Continue; the form is kept', (
    tester,
  ) async {
    await open(tester);
    await fillValidForm(tester);
    await chooseVehicle(tester, VehicleType.bicycle);

    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    await submit(tester);

    expect(byKey('register-error'), findsOneWidget);
    expect(find.byType(RegistrationScreen), findsOneWidget);

    await submit(tester);
    expect(find.text('Finish your application'), findsOneWidget);
    expect(find.text('0 of 4 uploaded'), findsOneWidget);
  });

  testWidgets('stores fail to load: error with Retry', (tester) async {
    h.onboarding.failNext = const ApiError(code: ApiErrorCode.timeout);
    await open(tester);

    await show(tester, 'register-stores-retry');
    expect(byKey('register-stores-error'), findsOneWidget);
    await tester.tap(byKey('register-stores-retry'));
    await tester.pumpAndSettle();

    expect(byKey('register-store'), findsOneWidget);
    expect(h.onboarding.calls, ['fetchStores', 'fetchStores']);
  });

  group('email sign-up (has_phone false): contact_phone', () {
    Future<void> openEmail(WidgetTester tester) async {
      h.backend.seedVerifiedEmailOnly = 'ravi@example.com';
      await open(tester);
    }

    // The Mobile number sits near the top: scroll back up to it.
    Future<void> showUp(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(
        byKey(key),
        -150,
        scrollable: find
            .descendant(of: find.byKey(form), matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a phone account sees no Mobile number field', (tester) async {
      await open(tester);
      expect(byKey('register-contact-phone'), findsNothing);
    });

    testWidgets('the Mobile number is required and sent as contact_phone', (
      tester,
    ) async {
      await openEmail(tester);
      expect(byKey('register-contact-phone'), findsOneWidget);
      await fillValidForm(tester);
      await chooseVehicle(tester, VehicleType.bicycle);
      await submit(tester);
      await showUp(tester, 'register-contact-phone');
      expect(find.text('This is required.'), findsOneWidget);
      expect(h.onboarding.calls, isNot(contains('register')));

      await tester.enterText(byKey('register-contact-phone'), '9811122299');
      await submit(tester);
      expect(h.onboarding.calls, contains('register'));
      final profile = h.onboarding.profileOf('user-57')!;
      expect(profile.contactPhone, '+919811122299');
    });

    testWidgets('the emergency number must differ from the Mobile number', (
      tester,
    ) async {
      await openEmail(tester);
      await fillValidForm(tester);
      await chooseVehicle(tester, VehicleType.bicycle);
      await showUp(tester, 'register-contact-phone');
      await tester.enterText(byKey('register-contact-phone'), '9876500001');
      await submit(tester);
      await show(tester, 'register-emergency-phone');
      expect(
        find.text("Enter someone else's number, not your own."),
        findsOneWidget,
      );
      expect(h.onboarding.calls, isNot(contains('register')));
    });

    testWidgets('400 VALIDATION_ERROR on contact_phone shows under the '
        'field', (tester) async {
      await openEmail(tester);
      await fillValidForm(tester);
      await chooseVehicle(tester, VehicleType.bicycle);
      await showUp(tester, 'register-contact-phone');
      await tester.enterText(byKey('register-contact-phone'), '9811122299');
      h.onboarding.failNext = const ApiError(
        code: ApiErrorCode.validationError,
        rawCode: 'VALIDATION_ERROR',
        statusCode: 400,
        details: {
          'contact_phone': ['Enter a valid number.'],
        },
      );
      await submit(tester);
      await showUp(tester, 'register-contact-phone');
      expect(
        find.text(
          'Enter a valid Indian mobile number starting with 6, 7, 8 or 9.',
        ),
        findsOneWidget,
      );
    });
  });

  group('RA-07', () {
    testWidgets('the selected vehicle tile shows a check mark', (tester) async {
      await open(tester);
      expect(byKey('register-vehicle-SCOOTER-check'), findsNothing);

      await chooseVehicle(tester, VehicleType.scooter);
      expect(byKey('register-vehicle-SCOOTER-check'), findsOneWidget);
      expect(byKey('register-vehicle-BICYCLE-check'), findsNothing);
    });

    testWidgets('the form survives the app being stopped, and is cleared '
        'once registration succeeds', (tester) async {
      await open(tester);
      await fillValidForm(tester);
      await chooseVehicle(tester, VehicleType.bicycle);
      await tester.pump(const Duration(seconds: 1));
      expect(h.registrationDraft.draft?.emergencyName, 'Sunita Kumar');

      // Android stopped the app: a fresh widget tree, same phone storage.
      await tester.pumpWidget(const SizedBox());
      await h.pump(tester);
      await show(tester, 'register-emergency-phone');
      expect(
        tester
            .widget<TextField>(byKey('register-emergency-phone'))
            .controller!
            .text,
        '9876500001',
      );
      await show(tester, 'register-vehicle-BICYCLE');
      expect(byKey('register-vehicle-BICYCLE-check'), findsOneWidget);

      await submit(tester);
      expect(h.onboarding.calls, contains('register'));
      expect(h.registrationDraft.draft, isNull);
    });

    testWidgets('signing out inside the 400 ms save window leaves no form '
        'behind (timer and dispose do not write after the clear)', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(byKey('register-emergency-name'), 'Sunita');
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.registrationDraft.draft, isNull, reason: 'not saved yet');

      await h.session.signOut(reason: SignOutReason.sessionExpired);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsNothing);
      expect(h.registrationDraft.draft, isNull);
    });

    testWidgets('sign-out deletes the saved form', (tester) async {
      await open(tester);
      await tester.enterText(byKey('register-emergency-name'), 'Sunita');
      await tester.pump(const Duration(seconds: 1));
      expect(h.registrationDraft.draft, isNotNull);

      await h.session.signOut(reason: SignOutReason.userRequested);
      await tester.pumpAndSettle();
      expect(h.registrationDraft.draft, isNull);
    });
  });
}
