import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

void main() {
  group('AppEnv.resolve', () {
    test('dev defaults to the emulator host on port 8001', () {
      final env = AppEnv.resolve(flavor: Flavor.dev);

      expect(env.apiBaseUrl, Uri.parse('http://10.0.2.2:8001'));
      expect(env.sentryDsn, isNull);
      expect(env.useFakeApi, isFalse);
      expect(env.isProd, isFalse);
      expect(env.environmentName, 'dev');
    });

    test('an explicit API_BASE_URL wins over the dev default', () {
      final env = AppEnv.resolve(
        flavor: Flavor.dev,
        apiBaseUrl: 'http://192.168.1.20:8001',
      );

      expect(env.apiBaseUrl, Uri.parse('http://192.168.1.20:8001'));
    });

    test('trailing slashes and whitespace are removed', () {
      final env = AppEnv.resolve(
        flavor: Flavor.staging,
        apiBaseUrl: '  https://staging-api.example.in/  ',
      );

      expect(env.apiBaseUrl.toString(), 'https://staging-api.example.in');
    });

    for (final flavor in [Flavor.staging, Flavor.prod]) {
      test('${flavor.name} requires API_BASE_URL', () {
        expect(
          () => AppEnv.resolve(flavor: flavor),
          throwsA(isA<EnvConfigException>()),
        );
      });
    }

    test('rejects values that are not absolute http(s) URLs', () {
      for (final bad in [
        'api.example.in',
        'ftp://api.example.in',
        'https://',
        'not a url',
      ]) {
        expect(
          () => AppEnv.resolve(flavor: Flavor.staging, apiBaseUrl: bad),
          throwsA(isA<EnvConfigException>()),
          reason: bad,
        );
      }
    });

    test('prod rejects plain http', () {
      expect(
        () => AppEnv.resolve(
          flavor: Flavor.prod,
          apiBaseUrl: 'http://api.example.in',
        ),
        throwsA(isA<EnvConfigException>()),
      );
      expect(
        AppEnv.resolve(
          flavor: Flavor.prod,
          apiBaseUrl: 'https://api.example.in',
        ).isProd,
        isTrue,
      );
    });

    test('an empty Sentry DSN disables Sentry', () {
      expect(
        AppEnv.resolve(flavor: Flavor.dev, sentryDsn: '   ').sentryDsn,
        isNull,
      );
      expect(
        AppEnv.resolve(
          flavor: Flavor.dev,
          sentryDsn: 'https://key@sentry.example/1',
        ).sentryDsn,
        'https://key@sentry.example/1',
      );
    });

    test('FAKE_API works in dev and staging but never in prod', () {
      expect(
        AppEnv.resolve(flavor: Flavor.dev, useFakeApi: true).useFakeApi,
        isTrue,
      );
      expect(
        AppEnv.resolve(
          flavor: Flavor.staging,
          apiBaseUrl: 'https://staging-api.example.in',
          useFakeApi: true,
        ).useFakeApi,
        isTrue,
      );
      expect(
        AppEnv.resolve(
          flavor: Flavor.prod,
          apiBaseUrl: 'https://api.example.in',
          useFakeApi: true,
        ).useFakeApi,
        isFalse,
      );
    });
  });

  test('fromEnvironment uses the dev default when nothing is defined', () {
    // Tests run without --dart-define, so this exercises the defaults.
    expect(
      AppEnv.fromEnvironment(Flavor.dev),
      AppEnv.resolve(flavor: Flavor.dev),
    );
  });
}
