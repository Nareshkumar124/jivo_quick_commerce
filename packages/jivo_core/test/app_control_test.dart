import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import 'support/fake_backend.dart';

const clientInfo = ClientInfo(
  appName: 'rider',
  appVersion: '1.0.0',
  platform: 'android',
);

void main() {
  late AppControlSignals signals;
  late List<AppControlEvent> events;

  setUp(() {
    signals = AppControlSignals();
    events = [];
    signals.events.listen(events.add);
  });

  tearDown(() => signals.dispose());

  Future<DioException> call(int status, Object? body) async {
    final dio = createJivoDio(
      env: AppEnv.resolve(flavor: Flavor.dev),
      clientInfo: clientInfo,
      interceptors: [AppControlInterceptor(signals)],
      logRequests: false,
      httpClientAdapter: FakeBackend((_) => (status, body)),
    );
    try {
      await dio.get<Object?>('/api/v1/addresses/');
    } on DioException catch (e) {
      await Future<void>.delayed(Duration.zero);
      return e;
    }
    fail('expected the call to fail');
  }

  test(
    '426 APP_UPDATE_REQUIRED raises AppUpdateRequired with its details',
    () async {
      final error = await call(
        426,
        envelope(
          'APP_UPDATE_REQUIRED',
          details: {
            'min_supported_version': '1.2.0',
            'latest_version': '1.4.0',
            'store_url':
                'https://play.google.com/store/apps/details?id=in.jivo.quick',
          },
        ),
      );

      final expected = AppUpdateRequired(
        minSupportedVersion: '1.2.0',
        latestVersion: '1.4.0',
        storeUrl: Uri.parse(
          'https://play.google.com/store/apps/details?id=in.jivo.quick',
        ),
      );
      expect(signals.current, expected);
      expect(events, [expected]);
      expect(
        ApiError.from(error).code,
        ApiErrorCode.appUpdateRequired,
        reason: 'the caller still gets the error',
      );
    },
  );

  test('426 without an envelope still raises AppUpdateRequired', () async {
    await call(426, null);

    expect(signals.current, const AppUpdateRequired());
  });

  test(
    '503 MAINTENANCE raises MaintenanceMode with the server message',
    () async {
      var notified = 0;
      signals.addListener(() => notified++);

      await call(503, envelope('MAINTENANCE', message: 'Back by 6:00 AM.'));

      expect(
        signals.current,
        const MaintenanceMode(message: 'Back by 6:00 AM.'),
      );
      expect(events, [const MaintenanceMode(message: 'Back by 6:00 AM.')]);
      expect(notified, 1);

      signals.clearMaintenance();
      expect(signals.current, isNull);
      expect(notified, 2);
    },
  );

  test('other 503s and other errors raise nothing', () async {
    await call(503, envelope('SERVICE_UNAVAILABLE'));
    await call(503, null);
    await call(500, envelope('SERVER_ERROR'));
    await call(401, envelope('TOKEN_INVALID'));

    expect(signals.current, isNull);
    expect(events, isEmpty);
  });

  test('a force update outranks maintenance', () async {
    await call(426, envelope('APP_UPDATE_REQUIRED'));
    await call(503, envelope('MAINTENANCE'));
    signals.clearMaintenance();

    expect(signals.current, isA<AppUpdateRequired>());
  });
}
