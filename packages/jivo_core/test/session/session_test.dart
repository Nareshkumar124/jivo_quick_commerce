import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../support/fake_backend.dart';

const oldTokens = AuthTokens(access: 'old-access', refresh: 'old-refresh');
const newTokens = AuthTokens(access: 'new-access', refresh: 'new-refresh');
const clientInfo = ClientInfo(
  appName: 'customer',
  appVersion: '1.0.0',
  platform: 'android',
);
const mePath = '/api/v1/me/';
const refreshPath = '/api/v1/auth/token/refresh/';

final meJson = {
  'id': 42,
  'phone': '+919876543210',
  'name': 'Asha',
  'is_profile_complete': true,
  'rider_status': 'NONE',
  'created_at': '2026-11-02T10:15:00Z',
};

/// One app wired the way an app wires it: session + refresher on a
/// dedicated Dio + main Dio with the auth and app-control interceptors.
class Harness {
  Harness({
    required FutureOr<(int, Object?)> Function(RequestOptions) api,
    required FutureOr<(int, Object?)> Function(RequestOptions) refresh,
    AuthTokens? stored = oldTokens,
  }) : store = InMemoryTokenStore(stored),
       apiBackend = FakeBackend(api),
       refreshBackend = FakeBackend(refresh) {
    final env = AppEnv.resolve(flavor: Flavor.dev);
    session = SessionManager(
      store: store,
      refresher: ApiTokenRefresher.forEnv(
        env: env,
        clientInfo: clientInfo,
        httpClientAdapter: refreshBackend,
        logRequests: false,
      ),
    );
    dio = createJivoDio(
      env: env,
      clientInfo: clientInfo,
      interceptors: [AuthInterceptor(session), AppControlInterceptor(signals)],
      logRequests: false,
      httpClientAdapter: apiBackend,
    );
    client = JivoApi(dio: dio, interceptors: const []);
  }

  final InMemoryTokenStore store;
  final FakeBackend apiBackend;
  final FakeBackend refreshBackend;
  final AppControlSignals signals = AppControlSignals();
  late final SessionManager session;
  late final Dio dio;
  late final JivoApi client;

  /// `GET /api/v1/me/` through the generated client (a secured operation).
  Future<int?> getMe() async {
    final response = await client.getAccountApi().meRetrieve();
    return response.statusCode;
  }
}

/// `/me/` answers 200 for the new access token and 401 otherwise.
(int, Object?) meAcceptsNewToken(RequestOptions request) =>
    authorizationOf(request) == 'Bearer new-access'
    ? (200, meJson)
    : (401, envelope('TOKEN_INVALID'));

/// Waits (up to 5 s) until [condition] holds, instead of a fixed delay.
Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

class ThrowingSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => throw PlatformException(code: 'BadPaddingException');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

class ThrowingTokenStore implements TokenStore {
  @override
  Future<AuthTokens?> read() => throw StateError('keystore unavailable');

  @override
  Future<void> write(AuthTokens tokens) async {}

  @override
  Future<void> clear() => throw StateError('keystore unavailable');
}

void main() {
  group('auth interceptor and refresh', () {
    test(
      'concurrent 401s trigger exactly one refresh; all requests then succeed',
      () async {
        final h = Harness(
          api: meAcceptsNewToken,
          refresh: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return (200, newTokens.toJson());
          },
        );
        await h.session.restore();

        final statuses = await Future.wait([h.getMe(), h.getMe(), h.getMe()]);

        expect(statuses, [200, 200, 200]);
        expect(h.refreshBackend.requests, hasLength(1));
        final sent = h.apiBackend.requests.map(authorizationOf).toList();
        expect(sent.where((a) => a == 'Bearer old-access'), hasLength(3));
        expect(sent.where((a) => a == 'Bearer new-access'), hasLength(3));
      },
    );

    test(
      'a request started during a refresh waits and uses the new token',
      () async {
        final gate = Completer<void>();
        final h = Harness(
          api: meAcceptsNewToken,
          refresh: (_) async {
            await gate.future;
            return (200, newTokens.toJson());
          },
        );
        await h.session.restore();

        final first = h.getMe();
        await until(() => h.refreshBackend.requests.isNotEmpty);
        final second = h.getMe(); // starts while the refresh is in flight
        await Future<void>.delayed(Duration.zero);
        gate.complete();

        expect(await Future.wait([first, second]), [200, 200]);
        expect(h.refreshBackend.requests, hasLength(1));
        // first: old (401) + retry; second: only the new token.
        expect(h.apiBackend.requests, hasLength(3));
      },
    );

    test(
      'rotation persists both new tokens and sends the old refresh token',
      () async {
        final h = Harness(
          api: meAcceptsNewToken,
          refresh: (_) => (200, newTokens.toJson()),
        );
        await h.session.restore();

        await h.getMe();

        expect(await h.store.read(), newTokens);
        expect(h.session.accessToken, 'new-access');
        expect(h.session.refreshToken, 'new-refresh');
        final body = h.refreshBackend.requests.single.data;
        expect(body is String ? jsonDecode(body) : body, {
          'refresh': 'old-refresh',
        });
      },
    );

    test('the refresh request carries no Authorization header', () async {
      final h = Harness(
        api: meAcceptsNewToken,
        refresh: (_) => (200, newTokens.toJson()),
      );
      await h.session.restore();

      await h.getMe();

      final refresh = h.refreshBackend.requests.single;
      expect(refresh.method, 'POST');
      expect(refresh.path, refreshPath);
      expect(authorizationOf(refresh), isNull);
      expect(refresh.headers['X-App-Name'], 'customer');
    });

    test('refresh 401 TOKEN_INVALID signs the user out', () async {
      final h = Harness(
        api: meAcceptsNewToken,
        refresh: (_) => (401, envelope('TOKEN_INVALID')),
      );
      await h.session.restore();
      final hookReasons = <SignOutReason>[];
      h.session.addSignOutHook((reason) async {
        hookReasons.add(reason);
        // A hook calling the API must not deadlock on the ending refresh.
        await h.getMe().catchError((Object _) => null);
      });
      final statuses = <SessionStatus>[];
      final sub = h.session.statusStream.listen(statuses.add);

      final error = await h
          .getMe()
          .timeout(const Duration(seconds: 5))
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(ApiError.from(error!).code, ApiErrorCode.tokenInvalid);

      expect(
        authorizationOf(h.apiBackend.requests.last),

        isNull,

        reason: 'the hook ran signed out',
      );
      expect(h.session.status, SessionStatus.signedOut);
      expect(h.session.lastSignOutReason, SignOutReason.sessionExpired);
      expect(h.session.accessToken, isNull);
      expect(await h.store.read(), isNull);
      expect(hookReasons, [SignOutReason.sessionExpired]);
      await Future<void>.delayed(Duration.zero);
      expect(statuses, [SessionStatus.signedOut]);
      await sub.cancel();
    });

    test('a network error during refresh keeps the session', () async {
      var refreshWorks = false;
      final h = Harness(
        api: meAcceptsNewToken,
        refresh: (_) {
          if (!refreshWorks) {
            throw const SocketException('Network is unreachable');
          }
          return (200, newTokens.toJson());
        },
      );
      await h.session.restore();

      final error = await h.getMe().then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );

      expect(ApiError.from(error!).code, ApiErrorCode.network);
      expect(h.session.status, SessionStatus.signedIn);
      expect(await h.store.read(), oldTokens);

      refreshWorks = true;
      expect(await h.getMe(), 200, reason: 'the kept session recovers');
    });

    test('a 5xx during refresh also keeps the session', () async {
      final h = Harness(
        api: meAcceptsNewToken,
        refresh: (_) => (503, envelope('SERVICE_UNAVAILABLE')),
      );
      await h.session.restore();

      await expectLater(h.getMe(), throwsA(isA<DioException>()));
      expect(h.session.status, SessionStatus.signedIn);
    });

    test('a request is retried only once', () async {
      final h = Harness(
        api: (_) => (401, envelope('TOKEN_INVALID')),
        refresh: (_) => (200, newTokens.toJson()),
      );
      await h.session.restore();

      await expectLater(h.getMe(), throwsA(isA<DioException>()));
      expect(h.refreshBackend.requests, hasLength(1));
      expect(h.apiBackend.requests, hasLength(2));
    });

    test('public operations never carry the token; secured ones do', () async {
      final h = Harness(
        api: (request) =>
            request.path == mePath ? (200, meJson) : (200, {'status': 'ok'}),
        refresh: (_) => (500, null),
      );
      await h.session.restore();

      await h.client
          .getHealthApi()
          .healthLive(); // public: `security` lists none
      await h.getMe(); // secured: jwtAuth
      await h.dio.get<Object?>('/api/v1/custom/'); // hand-written, no opt-in
      await h.dio.get<Object?>(
        '/api/v1/custom/',
        options: Options(extra: {AuthInterceptor.requiresAuthKey: true}),
      );

      expect(h.apiBackend.requests.map(authorizationOf).toList(), [
        null,
        'Bearer old-access',
        null,
        'Bearer old-access',
      ]);
    });

    test('a 401 while signed out does not refresh', () async {
      final h = Harness(
        api: (_) => (401, envelope('AUTH_REQUIRED')),
        refresh: (_) => (200, newTokens.toJson()),
        stored: null,
      );
      await h.session.restore();

      await expectLater(h.getMe(), throwsA(isA<DioException>()));
      expect(authorizationOf(h.apiBackend.requests.single), isNull);
      expect(h.refreshBackend.requests, isEmpty);
    });

    test(
      'signing out during a refresh does not bring the session back',
      () async {
        final gate = Completer<void>();
        final h = Harness(
          api: meAcceptsNewToken,
          refresh: (_) async {
            await gate.future;
            return (200, newTokens.toJson());
          },
        );
        await h.session.restore();

        final request = h.getMe().then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        await until(() => h.refreshBackend.requests.isNotEmpty);
        await h.session.signOut();
        gate.complete();
        await request;

        expect(h.session.status, SessionStatus.signedOut);
        expect(h.session.accessToken, isNull);
        expect(await h.store.read(), isNull);
      },
    );
  });

  test(
    'request metadata never holds the token (it is logged in debug)',
    () async {
      final h = Harness(
        api: meAcceptsNewToken,
        refresh: (_) => (200, newTokens.toJson()),
      );
      await h.session.restore();

      await h.getMe();

      for (final request in h.apiBackend.requests) {
        final extras = request.extra.values.map((v) => '$v').join(' ');
        expect(extras, isNot(contains('access')), reason: extras);
      }
    },
  );

  group('SessionManager state', () {
    SessionManager sessionWith(TokenStore store) => SessionManager(
      store: store,
      refresher: ApiTokenRefresher.forEnv(
        env: AppEnv.resolve(flavor: Flavor.dev),
        clientInfo: clientInfo,
        httpClientAdapter: FakeBackend((_) => (500, null)),
        logRequests: false,
      ),
    );

    test('restore, signIn and signOut drive the status and notify', () async {
      final store = InMemoryTokenStore();
      final session = sessionWith(store);
      var notifications = 0;
      session.addListener(() => notifications++);
      expect(session.status, SessionStatus.unknown);

      await session.restore();
      expect(session.status, SessionStatus.signedOut);

      await session.signIn(newTokens);
      expect(session.isSignedIn, isTrue);
      expect(await store.read(), newTokens);

      await session.signOut();
      expect(session.status, SessionStatus.signedOut);
      expect(session.lastSignOutReason, SignOutReason.userRequested);
      expect(await store.read(), isNull);
      expect(notifications, 3);
    });

    test('restore signs in from stored tokens', () async {
      final session = sessionWith(InMemoryTokenStore(oldTokens));

      await session.restore();

      expect(session.isSignedIn, isTrue);
      expect(session.accessToken, 'old-access');
    });

    test('sign-out hooks run before listeners hear signedOut; a failing hook does not block', () async {
      final session = sessionWith(InMemoryTokenStore(oldTokens));
      await session.restore();
      final order = <String>[];
      session.addSignOutHook((_) async => throw StateError('hook failed'));
      final remove = session.addSignOutHook((_) async => order.add('removed'));
      remove();
      session.addSignOutHook((_) async => order.add('hook'));
      session.addListener(() => order.add('listener:${session.status.name}'));

      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await session.signOut();

      expect(order, ['hook', 'listener:signedOut']);
      expect(reported, hasLength(1));
    });
  });

  group('SecureTokenStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('writes both tokens as one entry and reads them back', () async {
      final storage = const FlutterSecureStorage();
      final store = SecureTokenStore(storage: storage);

      await store.write(newTokens);

      final all = await storage.readAll();
      expect(all.keys, [SecureTokenStore.defaultKey]);
      expect(jsonDecode(all[SecureTokenStore.defaultKey]!), newTokens.toJson());
      expect(await store.read(), newTokens);

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('an unreadable entry is cleared and treated as signed out', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureTokenStore.defaultKey: '{"access": "only-access"}',
      });
      final storage = const FlutterSecureStorage();

      expect(await SecureTokenStore(storage: storage).read(), isNull);
      expect(await storage.readAll(), isEmpty);
    });

    test('a storage read failure counts as signed out', () async {
      final store = SecureTokenStore(storage: ThrowingSecureStorage());

      expect(await store.read(), isNull);
    });

    test('restore survives a failing store and reports signed out', () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final session = SessionManager(
        store: ThrowingTokenStore(),
        refresher: ApiTokenRefresher.forEnv(
          env: AppEnv.resolve(flavor: Flavor.dev),
          clientInfo: clientInfo,
          httpClientAdapter: FakeBackend((_) => (500, null)),
          logRequests: false,
        ),
      );

      await session.restore();
      expect(session.status, SessionStatus.signedOut);

      await session.signIn(newTokens);
      await session.signOut(); // clear() throws: still signs out
      expect(session.status, SessionStatus.signedOut);
      expect(session.accessToken, isNull);
      expect(reported, hasLength(2));
    });

    test('tokens never appear in toString', () {
      expect(newTokens.toString(), isNot(contains('new-access')));
    });
  });
}
