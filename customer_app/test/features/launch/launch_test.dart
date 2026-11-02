import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/presentation/auth_flow.dart';
import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:customer_app/features/launch/domain/launch_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

LaunchConfig configWith({
  String? min,
  String? latest,
  bool maintenance = false,
  String? message,
}) => LaunchConfig(
  maintenance: maintenance,
  maintenanceMessage: message,
  termsVersion: '2026-11-01',
  policies: FakeConfigRepository.sample.policies,
  minSupportedVersion: min,
  latestVersion: latest,
  storeUrl: Uri.parse(
    'https://play.google.com/store/apps/details?id=in.jivo.quick',
  ),
);

void main() {
  testWidgets('first launch shows onboarding, which can be skipped', (
    tester,
  ) async {
    final app = TestApp(onboardingSeen: false);
    await app.pump(tester);
    expect(find.text('Wellness, delivered fast'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Log in or sign up'), findsOneWidget);
  });

  testWidgets(
    'below min_supported_version: blocking update screen with a store link',
    (tester) async {
      final app = TestApp(appVersion: '1.0.0');
      app.config.config = configWith(min: '1.2.0', latest: '1.4.0');
      await app.pump(tester);

      expect(find.text('Update required'), findsOneWidget);
      await tester.tap(find.text('Update now'));
      expect(app.urls.opened.single.host, 'play.google.com');
    },
  );

  testWidgets('below latest_version only: a dismissible prompt on home', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens, appVersion: '1.0.0');
    app.config.config = configWith(min: '1.0.0', latest: '1.4.0');
    await app.pump(tester);

    expect(find.text('A new version of Jivo is available.'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('A new version of Jivo is available.'), findsNothing);
  });

  testWidgets(
    'maintenance shows the server message; Try again leaves when it ends',
    (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.config.config = configWith(
        maintenance: true,
        message: 'Back by 6:00 AM.',
      );
      await app.pump(tester);
      expect(find.text('Back by 6:00 AM.'), findsOneWidget);

      app.config.config = configWith();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hi, '), findsOneWidget);
    },
  );

  testWidgets('a 503 MAINTENANCE from any call routes to maintenance', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    app.signals.reportMaintenance(const MaintenanceMode());
    await tester.pumpAndSettle();

    expect(find.text("We'll be back soon"), findsOneWidget);
  });

  testWidgets('a config failure shows Retry, which recovers', (tester) async {
    final app = TestApp();
    app.config.failWith = const ApiError(code: ApiErrorCode.network);
    await app.pump(tester);
    expect(
      find.text('No internet connection. Check your connection and try again.'),
      findsOneWidget,
    );

    app.config.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Log in or sign up'), findsOneWidget);
  });

  testWidgets('the offline banner follows connectivity', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    expect(find.text('No internet connection'), findsNothing);

    app.connectivity.add(false);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);

    app.connectivity.add(true);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsNothing);
  });

  test(
    'logout also revokes a token rotated by the logout call itself',
    () async {
      final session = SessionManager(
        store: InMemoryTokenStore(signedInTokens),
        refresher: _NoRefresh(),
      );
      await session.restore();
      final auth = _RotatingLogout(session);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWithValue(session),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await container.read(logoutProvider)();

      expect(auth.revoked, ['r1', 'r2']);
      expect(session.isSignedIn, isFalse);
    },
  );

  test('logout signs out locally even when the call fails', () async {
    final session = SessionManager(
      store: InMemoryTokenStore(signedInTokens),
      refresher: _NoRefresh(),
    );
    await session.restore();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWithValue(session),
        authRepositoryProvider.overrideWithValue(_FailingLogout()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(logoutProvider)();

    expect(session.isSignedIn, isFalse);
  });

  test('LaunchState tracks the update prompt once per start', () {
    final state = LaunchState(onboardingSeen: true)
      ..configLoaded(configWith(latest: '2.0.0'), updateAvailable: true);
    expect(state.showUpdatePrompt, isTrue);
    state.dismissUpdatePrompt();
    expect(state.showUpdatePrompt, isFalse);
  });
}

class _NoRefresh implements TokenRefresher {
  @override
  Future<AuthTokens> refresh(String refreshToken) => throw UnimplementedError();
}

/// Simulates an expired access token: the logout call rotates the pair
/// (as the auth interceptor's refresh would) before revoking the old token.
class _RotatingLogout extends FakeAuthRepository {
  _RotatingLogout(this.session);

  final SessionManager session;
  final List<String> revoked = [];

  @override
  Future<void> logout(String refreshToken) async {
    if (revoked.isEmpty) {
      await session.signIn(const AuthTokens(access: 'a2', refresh: 'r2'));
    }
    revoked.add(refreshToken);
  }
}

class _FailingLogout extends FakeAuthRepository {
  @override
  Future<void> logout(String refreshToken) async =>
      throw const ApiError(code: ApiErrorCode.network);
}
