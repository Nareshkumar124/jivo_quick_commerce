import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/features/auth/data/api_auth_repository.dart';
import 'package:rider_app/features/auth/presentation/phone_login_screen.dart';
import 'package:rider_app/features/realtime/data/rider_socket_message.dart';
import 'package:rider_app/features/realtime/presentation/rider_socket_providers.dart';
import 'package:rider_app/shared/errors/wrong_app.dart';
import 'package:rider_app/shared/errors/rider_error_text.dart';

import '../helpers/canned_http.dart';
import '../helpers/records_helpers.dart';
import '../helpers/rider_app_harness.dart';

/// DL-74: the rider API rejects customer-app tokens with 403
/// `PERMISSION_DENIED`, `details.reason` = `WRONG_APP_TOKEN` (or
/// `APP_HEADER_MISMATCH`, as this app always sends `X-App-Name: rider`).
void main() {
  const verifyPath = '/api/v1/auth/otp/verify/';
  const refreshPath = '/api/v1/auth/token/refresh/';
  const riderPath = '/api/v1/rider/tasks/current/';

  final riderClient = ClientInfo(
    appName: riderAppName,
    appVersion: '1.0.0',
    platform: 'android',
  );

  group('every request is a rider-app request', () {
    test('the app name is rider', () => expect(riderAppName, 'rider'));

    test('OTP verify sends X-App-Name: rider and app: rider', () async {
      final h = RiderTestHarness();
      expect(h.clientInfo.appName, riderAppName);
      final c = await h.container();
      final adapter = CannedAdapter();
      c.read(dioProvider).httpClientAdapter = adapter;

      await expectLater(
        ApiAuthRepository(c.read(jivoApiProvider)).verifyOtp(
          phoneE164: '+919000000001',
          otp: '123456',
          termsVersion: '1',
        ),
        throwsA(isA<ApiError>()),
      );

      final request = adapter.requests.single;
      expect(request.path, verifyPath);
      expect(request.headers[ClientInfo.appNameHeader], 'rider');
      expect(adapter.jsonBody(verifyPath)['app'], 'rider');
    });

    test('token refresh sends X-App-Name: rider', () async {
      final adapter = CannedAdapter()
        ..answers[refreshPath] = const Canned(200, {
          'access': 'a2',
          'refresh': 'r2',
        });
      final refresher = ApiTokenRefresher.forEnv(
        env: AppEnv(
          flavor: Flavor.staging,
          apiBaseUrl: Uri.parse('https://api.example.test'),
        ),
        clientInfo: riderClient,
        httpClientAdapter: adapter,
        logRequests: false,
      );

      final tokens = await refresher.refresh('r1');

      expect(tokens.access, 'a2');
      expect(
        adapter.requests.single.headers[ClientInfo.appNameHeader],
        'rider',
      );
    });
  });

  group('403 wrong app (DL-74)', () {
    ApiError denied(String reason, {int status = 403}) => ApiError(
      code: ApiErrorCode.permissionDenied,
      rawCode: 'PERMISSION_DENIED',
      statusCode: status,
      details: {'reason': reason},
    );

    test('WRONG_APP_TOKEN and APP_HEADER_MISMATCH are wrong-app', () {
      expect(WrongApp.isWrongApp(denied('WRONG_APP_TOKEN')), isTrue);
      expect(WrongApp.isWrongApp(denied('APP_HEADER_MISMATCH')), isTrue);
      // No separate top-level code: PERMISSION_DENIED + reason only.
      expect(
        WrongApp.isWrongApp(
          const ApiError(
            code: ApiErrorCode.unknown,
            rawCode: 'WRONG_APP',
            statusCode: 403,
          ),
        ),
        isFalse,
      );
    });

    test('other 403 reasons and other statuses are not', () {
      expect(WrongApp.isWrongApp(denied('RIDER_NOT_ACTIVE')), isFalse);
      expect(
        WrongApp.isWrongApp(denied('WRONG_APP_TOKEN', status: 400)),
        isFalse,
      );
      expect(WrongApp.isWrongAppSocketCode('WRONG_APP_TOKEN'), isTrue);
      expect(WrongApp.isWrongAppSocketCode('AUTH_REQUIRED'), isFalse);
    });

    testWidgets('logs the rider out with "log in with the Jivo Rider app"', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await pumpActiveHome(tester, h);
      final c = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('home-flavor'))),
      );
      final adapter = CannedAdapter()
        ..answers[riderPath] = Canned(
          403,
          errorBody('PERMISSION_DENIED', {'reason': 'WRONG_APP_TOKEN'}),
        );
      c.read(dioProvider).httpClientAdapter = adapter;

      // Dio runs on real timers.
      Object? thrown;
      await tester.runAsync(() async {
        try {
          await c.read(dioProvider).get<Object?>(riderPath);
        } on Object catch (e) {
          thrown = e;
        }
      });
      expect(thrown, isA<DioException>());
      await tester.pumpAndSettle();

      expect(h.session.isSignedIn, isFalse);
      expect(h.session.lastSignOutReason, SignOutReason.sessionExpired);
      expect(find.byType(PhoneLoginScreen), findsOneWidget);
      expect(
        find.text('Please log in with the Jivo Rider app.'),
        findsOneWidget,
      );
      expect(byKey('login-session-expired'), findsNothing);

      // The single error mapper says the same.
      final context = tester.element(find.byType(PhoneLoginScreen));
      expect(
        riderApiErrorMessage(context, denied('APP_HEADER_MISMATCH')),
        'Please log in with the Jivo Rider app.',
      );
    });

    testWidgets('another 403 keeps the session', (tester) async {
      final h = RiderTestHarness();
      await pumpActiveHome(tester, h);
      final c = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('home-flavor'))),
      );
      c.read(dioProvider).httpClientAdapter = CannedAdapter()
        ..answers[riderPath] = Canned(
          403,
          errorBody('PERMISSION_DENIED', {'reason': 'RIDER_NOT_ACTIVE'}),
        );

      // Dio runs on real timers.
      Object? thrown;
      await tester.runAsync(() async {
        try {
          await c.read(dioProvider).get<Object?>(riderPath);
        } on Object catch (e) {
          thrown = e;
        }
      });
      expect(thrown, isA<DioException>());
      await tester.pumpAndSettle();

      expect(h.session.isSignedIn, isTrue);
      expect(c.read(wrongAppNoticeProvider), isFalse);
    });

    testWidgets('the rider socket error WRONG_APP_TOKEN logs out too', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await pumpActiveHome(tester, h);
      final c = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('home-flavor'))),
      );

      c
          .read(riderSocketControllerProvider.notifier)
          .handle(const SocketError('WRONG_APP_TOKEN'));
      await tester.pumpAndSettle();

      expect(h.session.isSignedIn, isFalse);
      expect(
        find.text('Please log in with the Jivo Rider app.'),
        findsOneWidget,
      );
    });
  });
}
