import 'dart:async';

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/auth/data/otp_autofill.dart';
import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:customer_app/features/profile/data/profile_repository.dart';
import 'package:customer_app/shared/connectivity/connectivity.dart';
import 'package:customer_app/shared/links/url_opener.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_config.dart';

const signedInTokens = AuthTokens(access: 'a1', refresh: 'r1');

/// The whole app on fakes: no plugin, network or platform channel is used.
class TestApp {
  TestApp({
    this.tokens,
    this.onboardingSeen = true,
    this.appVersion = '1.0.0',
    String? autofillCode,
  }) : autofill = FakeOtpAutofill(autofillCode);

  final AuthTokens? tokens;
  final bool onboardingSeen;
  final String appVersion;

  final config = FakeConfigRepository();
  final auth = FakeAuthRepository();
  final profile = FakeProfileRepository();
  final addresses = FakeAddressRepository();
  final location = FakeDeviceLocation();
  final FakeOtpAutofill autofill;
  final urls = FakeUrlOpener();
  final refresher = FakeTokenRefresher();
  final connectivity = StreamController<bool>.broadcast();
  final store = InMemoryTokenStore();
  late final SessionManager session;
  final signals = AppControlSignals();

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    SharedPreferences.setMockInitialValues({
      'installed': true,
      'onboarding_seen': onboardingSeen,
    });
    final prefs = await SharedPreferences.getInstance();
    if (tokens != null) await store.write(tokens!);
    session = SessionManager(store: store, refresher: refresher);
    await session.restore();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      customerAppRoot(
        env: testEnv,
        clientInfo: ClientInfo(
          appName: 'customer',
          appVersion: appVersion,
          platform: 'android',
        ),
        session: session,
        signals: signals,
        prefs: prefs,
        overrides: [
          configRepositoryProvider.overrideWithValue(config),
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profile),
          addressRepositoryProvider.overrideWithValue(addresses),
          deviceLocationProvider.overrideWithValue(location),
          otpAutofillProvider.overrideWithValue(autofill),
          urlOpenerProvider.overrideWithValue(urls),
          connectivityStreamProvider.overrideWithValue(connectivity.stream),
        ],
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}

/// Types the phone, taps Get OTP and lands on the OTP screen.
Future<void> loginToOtp(WidgetTester tester, String digits) async {
  await tester.enterText(find.byKey(const Key('login-phone')), digits);
  await tester.tap(find.text('Get OTP'));
  await tester.pumpAndSettle();
}
