import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../support/capture_adapter.dart';

void main() {
  const clientInfo = ClientInfo(
    appName: 'customer',
    appVersion: '1.2.3',
    buildNumber: '45',
    platform: 'android',
  );
  final env = AppEnv.resolve(flavor: Flavor.dev);

  Dio dioWith(
    CaptureAdapter adapter, {
    RequestHeadersBuilder? dynamicHeaders,
    List<Interceptor> interceptors = const [],
  }) => createJivoDio(
    env: env,
    clientInfo: clientInfo,
    dynamicHeaders: dynamicHeaders,
    interceptors: interceptors,
    logRequests: false,
    httpClientAdapter: adapter,
  );

  test('sends the client-info headers on every request', () async {
    final adapter = CaptureAdapter();
    final dio = dioWith(adapter);

    await dio.get<Object?>('/health/live');
    await dio.post<Object?>('/api/v1/auth/otp/', data: {'phone': '9999999999'});

    for (final request in adapter.requests) {
      expect(request.headers['X-App-Name'], 'customer');
      expect(request.headers['X-App-Version'], '1.2.3');
      expect(request.headers['X-Platform'], 'android');
    }
  });

  test('uses the env base URL and keeps /api/v1 paths as given', () async {
    final adapter = CaptureAdapter();

    await dioWith(adapter).get<Object?>('/api/v1/config/app/');

    expect(
      adapter.last.uri.toString(),
      'http://10.0.2.2:8001/api/v1/config/app/',
    );
  });

  test('dynamic headers are added at send time (X-Store-Id hook)', () async {
    final adapter = CaptureAdapter();
    String? storeId;
    final dio = dioWith(
      adapter,
      dynamicHeaders: (_) => {'X-Store-Id': ?storeId},
    );

    await dio.get<Object?>('/api/v1/catalog/categories/');
    expect(adapter.last.headers.containsKey('X-Store-Id'), isFalse);

    storeId = '12';
    await dio.get<Object?>('/api/v1/catalog/categories/');
    expect(adapter.last.headers['X-Store-Id'], '12');
  });

  test(
    'a header set on the request itself wins over the dynamic one',
    () async {
      final adapter = CaptureAdapter();
      final dio = dioWith(adapter, dynamicHeaders: (_) => {'X-Store-Id': '12'});

      await dio.get<Object?>(
        '/api/v1/cart/',
        options: Options(headers: {'x-store-id': '99'}),
      );

      expect(adapter.last.headers['x-store-id'], '99');
    },
  );

  test(
    'a failing header builder rejects the request instead of sending it',
    () async {
      final adapter = CaptureAdapter();
      final dio = dioWith(
        adapter,
        dynamicHeaders: (_) => throw StateError('no store'),
      );

      await expectLater(
        dio.get<Object?>('/api/v1/cart/'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'app interceptors run after the client-info headers (auth hook)',
    () async {
      final adapter = CaptureAdapter();
      final seen = <String?>[];
      final dio = dioWith(
        adapter,
        interceptors: [
          InterceptorsWrapper(
            onRequest: (options, handler) {
              seen.add(options.headers['X-App-Name'] as String?);
              options.headers['Authorization'] = 'Bearer test';
              handler.next(options);
            },
          ),
        ],
      );

      await dio.get<Object?>('/api/v1/me/');

      expect(seen, ['customer']);
      expect(adapter.last.headers['Authorization'], 'Bearer test');
    },
  );

  test('request logging is off unless asked for', () {
    final dio = dioWith(CaptureAdapter());
    expect(dio.interceptors.whereType<LogInterceptor>(), isEmpty);

    final logging = createJivoDio(
      env: env,
      clientInfo: clientInfo,
      logRequests: true,
    );
    expect(logging.interceptors.whereType<LogInterceptor>(), hasLength(1));
  });

  group('ClientInfo', () {
    test('headers and release name', () {
      expect(clientInfo.headers, {
        'X-App-Name': 'customer',
        'X-App-Version': '1.2.3',
        'X-Platform': 'android',
      });
      expect(clientInfo.release, 'jivo-customer@1.2.3+45');
    });

    test('platform names match the X-Platform contract', () {
      expect(ClientInfo.platformName(TargetPlatform.android), 'android');
      expect(ClientInfo.platformName(TargetPlatform.iOS), 'ios');
    });
  });
}
