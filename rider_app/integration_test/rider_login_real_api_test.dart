// Real-API integration test of the Phase 1 rider login (no fakes, no stubbed
// responses). Needs the local backend on the host at port 8001 and the
// backend's fixed-OTP test numbers (D-15). There is no emulator on this
// machine (CLAUDE.md): run it on the USB phone, only when nobody else is
// using it, with the host's port forwarded, then reinstall the normal dev
// build (`adb install -r`):
//
//   adb -s 9TY5KF8H49Z5YDON reverse tcp:8001 tcp:8001
//   flutter test integration_test/rider_login_real_api_test.dart \
//     --flavor dev -d 9TY5KF8H49Z5YDON \
//     --dart-define=API_BASE_URL=http://localhost:8001
//
// Repeatable: it starts and ends signed out (the stored tokens are cleared
// and the test logs out at the end).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/bootstrap.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/features/auth/domain/rider_account.dart';
import 'package:rider_app/features/auth/presentation/auth_providers.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/launch/presentation/launch_controller.dart';

/// A backend test number: OTP [validOtp], no SMS, `rider_status: NONE`.
const phoneDigits = '9000000002';
const phoneE164 = '+919000000002';
const validOtp = '123456';
const wrongOtp = '000000';

/// Observes requests only (never changes or answers them), so the test can
/// prove what the app sent.
class RequestRecorder extends Interceptor {
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.next(options);
  }

  List<RequestOptions> to(String path) =>
      requests.where((r) => r.path == path).toList();

  Map<String, dynamic> body(RequestOptions request) {
    final data = request.data;
    return (data is String ? jsonDecode(data) : data) as Map<String, dynamic>;
  }
}

class RunningApp {
  RunningApp(this.container, this.session, this.recorder);

  final ProviderContainer container;
  final SessionManager session;
  final RequestRecorder recorder;
}

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TestFailure('Timed out after $timeout waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppEnv env;
  late ClientInfo clientInfo;

  setUpAll(() async {
    env = AppEnv.fromEnvironment(Flavor.dev);
    clientInfo = await ClientInfo.fromPlatform(appName: riderAppName);
    // Start signed out even if an earlier run failed half-way.
    await SecureTokenStore().clear();
  });

  tearDownAll(() => SecureTokenStore().clear());

  /// Starts the app the way `bootstrap()` does: a new [SessionManager]
  /// restored from secure storage (so a second call is an app restart), the
  /// real refresher and the real network.
  Future<RunningApp> launch(WidgetTester tester) async {
    final session = SessionManager(
      store: SecureTokenStore(),
      refresher: ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo),
    );
    await session.restore();
    final signals = AppControlSignals();
    final recorder = RequestRecorder();
    final container = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: [
        ...riderAppOverrides(
          env: env,
          clientInfo: clientInfo,
          session: session,
          signals: signals,
        ),
        // The app's Dio (same interceptors as providers.dart) plus the
        // observe-only recorder.
        dioProvider.overrideWith((ref) {
          final dio = createJivoDio(
            env: env,
            clientInfo: clientInfo,
            interceptors: [
              AuthInterceptor(session),
              AppControlInterceptor(signals),
              recorder,
            ],
          );
          ref.onDispose(dio.close);
          return dio;
        }),
        // The test numbers send no SMS: nothing to read.
        otpAutofillProvider.overrideWithValue(const NoOtpAutofill()),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const RiderApp()),
    );
    return RunningApp(container, session, recorder);
  }

  Future<void> stop(WidgetTester tester, RunningApp app) async {
    await tester.pumpWidget(const SizedBox.shrink());
    app.container.dispose();
  }

  testWidgets('P1 rider login against the real backend: config, wrong OTP, '
      'NONE registration form, /me, restore, logout', (tester) async {
    expect(env.useFakeApi, isFalse, reason: 'this test must hit the backend');
    debugPrint('API: ${env.apiBaseUrl}, app ${clientInfo.appVersion}');

    // 1. Splash loads the real config/app, then phone login.
    var app = await launch(tester);
    await pumpUntil(tester, find.text('Log in to Jivo Rider'));
    final config = app.container.read(launchControllerProvider).config!;
    expect(config.termsVersion, isNotEmpty);
    expect(
      app.recorder.to('/api/v1/config/app/').single.headers,
      containsPair('X-App-Name', 'rider'),
    );
    debugPrint(
      'config/app: terms_version=${config.termsVersion}, '
      'min=${config.minSupportedVersion}, latest=${config.latestVersion}',
    );

    // 2. Phone login: OTP request with +91 and app: rider.
    await tester.enterText(find.byKey(const Key('login-phone')), phoneDigits);
    await tester.tap(find.byKey(const Key('login-get-otp')));
    await pumpUntil(tester, find.text('Enter the code'));
    final otpRequest = app.recorder.to('/api/v1/auth/otp/request/').single;
    expect(app.recorder.body(otpRequest), containsPair('phone', phoneE164));
    expect(app.recorder.body(otpRequest), containsPair('app', 'rider'));

    // 3. A wrong OTP: the real OTP_INVALID, with the attempts left.
    await tester.enterText(find.byKey(const Key('otp-code')), wrongOtp);
    final wrongCode = find.textContaining(
      RegExp(r'^Wrong code\. \d+ attempts? left\.$'),
    );
    await pumpUntil(tester, wrongCode);
    debugPrint(
      'wrong OTP shows: "${(wrongCode.evaluate().single.widget as Text).data}"',
    );

    // 4. The right OTP, with terms_version from config/app: NONE → the
    //    registration form (P5 lookahead; it submits to the fake until the
    //    rider API lands, so this test does not submit it).
    await tester.enterText(find.byKey(const Key('otp-code')), validOtp);
    await pumpUntil(tester, find.text('Become a Jivo rider'));
    expect(find.byKey(const Key('register-form')), findsOneWidget);
    final verifies = app.recorder.to('/api/v1/auth/otp/verify/');
    expect(verifies, hasLength(2));
    for (final verify in verifies) {
      expect(
        app.recorder.body(verify),
        containsPair('terms_version', config.termsVersion),
      );
      expect(app.recorder.body(verify), containsPair('app', 'rider'));
    }
    expect(app.session.isSignedIn, isTrue);
    final account = app.container.read(riderAccountControllerProvider);
    expect(account, isA<AccountLoaded>());
    expect((account as AccountLoaded).riderStatus, RiderStatusEnum.NONE);

    // 5. GET /me/ with the bearer token returns the phone.
    final me =
        (await app.container.read(jivoApiProvider).getAccountApi().meRetrieve())
            .data!;
    expect(me.phone, phoneE164);
    expect(me.riderStatus, RiderStatusEnum.NONE);
    final meRequest = app.recorder.to('/api/v1/me/').last;
    expect(meRequest.headers['Authorization'], startsWith('Bearer '));
    debugPrint(
      'GET /me/: id=${me.id} phone=${me.phone} rider_status=${me.riderStatus.value}',
    );

    // 6. Restart: the session comes back from secure storage and GET /me/
    //    routes to the registration form without logging in again.
    await stop(tester, app);
    app = await launch(tester);
    expect(app.session.status, SessionStatus.signedIn);
    await pumpUntil(tester, find.text('Become a Jivo rider'));
    expect(app.recorder.to('/api/v1/me/'), hasLength(1));
    expect(app.recorder.to('/api/v1/auth/otp/request/'), isEmpty);
    expect(app.recorder.to('/api/v1/auth/otp/verify/'), isEmpty);
    final refreshBeforeLogout = app.session.refreshToken!;

    // 7. Logout: POST /auth/logout/, tokens cleared, back to login.
    await tester.tap(find.byKey(const Key('logout')));
    await pumpUntil(tester, find.text('Log in to Jivo Rider'));
    final logout = app.recorder.to('/api/v1/auth/logout/').single;
    expect(
      app.recorder.body(logout),
      containsPair('refresh', refreshBeforeLogout),
    );
    expect(app.session.status, SessionStatus.signedOut);
    expect(await SecureTokenStore().read(), isNull);

    // The server revoked the refresh token: refreshing with it now fails.
    final refresher = ApiTokenRefresher.forEnv(
      env: env,
      clientInfo: clientInfo,
    );
    await expectLater(
      refresher.refresh(refreshBeforeLogout),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    debugPrint('after logout: refresh with the old token is rejected (401)');

    await stop(tester, app);
  });
}
