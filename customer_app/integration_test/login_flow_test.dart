// Phase 1 critical flow: phone → OTP → (complete profile) → home → add an
// address → account → logout. The device location is faked in both modes (a
// system permission dialog can't be tapped from a test); the address itself
// is saved through the API.
//
// On fakes (default; no backend needed):
//   flutter test integration_test --flavor dev -d <device>
// Against the real backend (local stack on port 8001; fixed test OTPs):
//   adb reverse tcp:8001 tcp:8001
//   flutter test integration_test --flavor dev -d <device> \
//     --dart-define=REAL_API=true --dart-define=API_BASE_URL=http://localhost:8001 \
//     --dart-define=TEST_PHONE=9000000002 --dart-define=TEST_OTP=123456
// `…001` is an existing customer (goes straight home); `…002`/`…003` are new
// users on their first login (complete-profile first), existing after that.
import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:customer_app/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const realApi = bool.fromEnvironment('REAL_API');
const phoneDigits = String.fromEnvironment(
  'TEST_PHONE',
  defaultValue: '9000000002',
);
const otp = String.fromEnvironment('TEST_OTP', defaultValue: '123456');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login flow: phone, OTP, profile, account, logout', (
    tester,
  ) async {
    final env = AppEnv.fromEnvironment(Flavor.dev);
    final clientInfo = await ClientInfo.fromPlatform(appName: customerAppName);
    await initializeFormatting();
    // In-memory session and flags: a run never reuses the device's stored
    // tokens and always starts at login.
    SharedPreferences.setMockInitialValues({
      'installed': true,
      'onboarding_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final session = SessionManager(
      store: InMemoryTokenStore(),
      refresher: realApi
          ? ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo)
          : FakeTokenRefresher(),
    );
    await session.restore();

    await tester.pumpWidget(
      customerAppRoot(
        env: env,
        clientInfo: clientInfo,
        session: session,
        signals: AppControlSignals(),
        prefs: prefs,
        overrides: [
          otpAutofillProvider.overrideWithValue(FakeOtpAutofill()),
          deviceLocationProvider.overrideWithValue(FakeDeviceLocation()),
          if (!realApi) ...[
            configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(),
            ),
            addressRepositoryProvider.overrideWithValue(
              FakeAddressRepository(),
            ),
          ],
        ],
      ),
    );
    await pumpUntilFound(tester, find.text('Log in or sign up'));

    await tester.enterText(find.byKey(const Key('login-phone')), phoneDigits);
    await tester.tap(find.text('Get OTP'));
    await pumpUntilFound(tester, find.text('Verify your number'));

    await tester.enterText(find.byKey(const Key('otp-field')), otp);
    final home = find.byKey(const Key('home-screen'));
    await pumpUntilFound(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w.key == const Key('home-screen') ||
            (w is Text && w.data == 'Tell us about you'),
      ),
    );
    expect(session.isSignedIn, isTrue);

    if (find.text('Tell us about you').evaluate().isNotEmpty) {
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Integration Tester',
      );
      await tester.tap(find.text('Continue'));
      await pumpUntilFound(tester, home);
    }
    expect(home, findsOneWidget);

    // Add an address from Account (the pin is the device location; the map
    // address form is bound in Phase 2 S2-B).
    await tester.tap(find.byTooltip('Account'));
    await pumpUntilFound(tester, find.text('Saved addresses'));
    await tester.tap(find.text('Saved addresses'));
    await pumpUntilFound(tester, find.text('Add address'));
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();
    expect(find.text('Location captured'), findsOneWidget);
    final house = 'Flat ${DateTime.now().millisecondsSinceEpoch % 1000}';
    for (final (key, value) in [
      ('house', house),
      ('street', 'MG Road'),
      ('city', 'New Delhi'),
      ('state', 'Delhi'),
      ('pincode', '110001'),
    ]) {
      await tester.enterText(find.byKey(Key('address-$key')), value);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    // The list summary ("<house>, MG Road, …"), not the form field.
    await pumpUntilFound(tester, find.textContaining('$house, MG Road'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.textContaining('+91$phoneDigits'));
    expect(find.textContaining('+91$phoneDigits'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 100);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await pumpUntilFound(tester, find.text('Log in or sign up'));

    expect(session.isSignedIn, isFalse);
    expect(find.text('Log in or sign up'), findsOneWidget);
  });
}
