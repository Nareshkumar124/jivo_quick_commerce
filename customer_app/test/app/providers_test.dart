import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_config.dart';

Future<ProviderContainer> containerFor(AppEnv env) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(env),
      clientInfoProvider.overrideWithValue(testClientInfo),
      sessionProvider.overrideWithValue(
        SessionManager(
          store: InMemoryTokenStore(),
          refresher: FakeTokenRefresher(),
        ),
      ),
      appControlProvider.overrideWithValue(AppControlSignals()),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the API repositories are used by default', () async {
    final container = await containerFor(testEnv);

    expect(
      container.read(configRepositoryProvider),
      isA<ApiConfigRepository>(),
    );
    expect(container.read(authRepositoryProvider), isA<ApiAuthRepository>());
  });

  test('FAKE_API swaps in fakes, but never in prod', () async {
    final fake = await containerFor(
      AppEnv.resolve(flavor: Flavor.dev, useFakeApi: true),
    );
    expect(fake.read(authRepositoryProvider), isA<FakeAuthRepository>());

    final prod = await containerFor(
      AppEnv.resolve(
        flavor: Flavor.prod,
        apiBaseUrl: 'https://api.example.in',
        useFakeApi: true,
      ),
    );
    expect(prod.read(authRepositoryProvider), isA<ApiAuthRepository>());
    expect(prod.read(analyticsProvider), isA<NoopAnalyticsClient>());
  });

  test(
    'the Dio carries client info, auth and app-control interceptors',
    () async {
      final container = await containerFor(testEnv);
      final dio = container.read(dioProvider);

      expect(dio.options.baseUrl, 'http://10.0.2.2:8001');
      final types = dio.interceptors.map((i) => i.runtimeType).toList();
      expect(
        types,
        containsAllInOrder([
          ClientInfoInterceptor,
          AuthInterceptor,
          AppControlInterceptor,
        ]),
      );
    },
  );
}
