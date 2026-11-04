import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/shared/session/store_synced_token_refresher.dart';

/// Rotates once per refresh token, like simplejwt with
/// BLACKLIST_AFTER_ROTATION. [latency] delays every answer.
class _RotatingServer implements TokenRefresher {
  _RotatingServer({this.latency = Duration.zero});

  final Duration latency;
  final used = <String>{};
  int calls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls++;
    final n = calls;
    // Decide who wins at request time (the server sees the first one).
    final won = used.add(refreshToken);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (!won) {
      throw const ApiError(code: ApiErrorCode.tokenInvalid, statusCode: 401);
    }
    return AuthTokens(access: 'a-$n', refresh: 'r-$n');
  }
}

/// The shared secure store, with slow writes (Keystore on a budget phone).
class _SlowStore implements TokenStore {
  _SlowStore(this.writeDelay);

  Duration writeDelay;
  AuthTokens? _value;
  int clears = 0;

  AuthTokens? get value => _value;

  @override
  Future<AuthTokens?> read() async => _value;

  @override
  Future<void> write(AuthTokens tokens) async {
    await Future<void>.delayed(writeDelay);
    _value = tokens;
  }

  @override
  Future<void> clear() async {
    clears++;
    _value = null;
  }
}

const _fastRetries = [
  Duration(milliseconds: 25),
  Duration(milliseconds: 50),
  Duration(milliseconds: 100),
  Duration(milliseconds: 200),
];

/// One isolate's session over the shared [store], as the app builds it.
SessionManager _session(
  _SlowStore store,
  TokenRefresher server, {
  List<Duration> retries = _fastRetries,
}) => SessionManager(
  store: GuardedTokenStore(store),
  refresher: StoreSyncedTokenRefresher(
    inner: server,
    store: store,
    retryDelays: retries,
  ),
);

void main() {
  const start = AuthTokens(access: 'a-0', refresh: 'r-0');

  test(
    'the other isolate already rotated: use the stored pair, no request',
    () async {
      final store = _SlowStore(Duration.zero)..write(start);
      await Future<void>.delayed(Duration.zero);
      await store.write(const AuthTokens(access: 'a-x', refresh: 'r-x'));
      final server = _RotatingServer();
      final refresher = StoreSyncedTokenRefresher(inner: server, store: store);

      final tokens = await refresher.refresh('r-0');
      expect(tokens.refresh, 'r-x');
      expect(server.calls, 0);
    },
  );

  test('both refreshes in flight, the winner writes slowly: the loser waits '
      'for the write and adopts the pair; nobody is signed out', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    store.writeDelay = const Duration(milliseconds: 150);
    final server = _RotatingServer(latency: const Duration(milliseconds: 20));
    final ui = _session(store, server);
    final service = _session(store, server);
    await ui.restore();
    await service.restore();

    // Both access tokens expired at the same moment: concurrent refreshes.
    final results = await Future.wait([
      service.refreshAfterUnauthorized(service.tokenGeneration),
      ui.refreshAfterUnauthorized(ui.tokenGeneration),
    ]);

    expect(results, everyElement(isA<RefreshSucceeded>()));
    expect(ui.isSignedIn, isTrue);
    expect(service.isSignedIn, isTrue);
    expect(ui.refreshToken, service.refreshToken);
    expect(store.value?.refresh, service.refreshToken);
    expect(store.clears, 0);
    expect(server.calls, 2, reason: 'one winner, one rejected loser');
  });

  test('control: the same race without the retry window would sign the '
      'loser out (what the window fixes)', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    store.writeDelay = const Duration(milliseconds: 150);
    final server = _RotatingServer(latency: const Duration(milliseconds: 20));
    final ui = _session(store, server, retries: const []);
    final service = _session(store, server, retries: const []);
    await ui.restore();
    await service.restore();

    final results = await Future.wait([
      service.refreshAfterUnauthorized(service.tokenGeneration),
      ui.refreshAfterUnauthorized(ui.tokenGeneration),
    ]);
    expect(results.last, isA<SessionEnded>());
    // Even then the guarded store keeps the winner's pair.
    expect(store.value?.refresh, service.refreshToken);
  });

  test('a write slower than the whole retry window: the loser ends its own '
      'session but never wipes the winner\'s fresh pair', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    store.writeDelay = const Duration(milliseconds: 600);
    final server = _RotatingServer();
    final winner = _session(store, server);
    final loser = _session(
      store,
      server,
      retries: const [Duration(milliseconds: 20)],
    );
    await winner.restore();
    await loser.restore();

    final winnerDone = winner.refreshAfterUnauthorized(winner.tokenGeneration);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final loserResult = await loser.refreshAfterUnauthorized(
      loser.tokenGeneration,
    );
    expect(loserResult, isA<SessionEnded>());

    expect(await winnerDone, isA<RefreshSucceeded>());
    expect(store.value?.refresh, winner.refreshToken, reason: 'kept');
    expect(winner.isSignedIn, isTrue);
  });

  test('a rejection with nothing newer in the store ends the session and '
      'clears it', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    final server = _RotatingServer()..used.add('r-0');
    final session = _session(store, server);
    await session.restore();

    final result = await session.refreshAfterUnauthorized(
      session.tokenGeneration,
    );
    expect(result, isA<SessionEnded>());
    expect(session.isSignedIn, isFalse);
    expect(store.value, isNull);
  });

  test('a deliberate logout clears even a pair the UI never saw', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    final guarded = GuardedTokenStore(store);
    await guarded.read();
    await store.write(const AuthTokens(access: 'a-s', refresh: 'r-s'));

    await guarded.clear();
    expect(store.value, isNotNull, reason: 'plain clear keeps the newer pair');
    await guarded.clearUnconditionally();
    expect(store.value, isNull);
  });

  test('a transient failure is passed on unchanged, without waiting', () async {
    final store = _SlowStore(Duration.zero);
    await store.write(start);
    var waited = false;
    final refresher = StoreSyncedTokenRefresher(
      inner: _Failing(),
      store: store,
      sleep: (_) async => waited = true,
    );
    await expectLater(
      refresher.refresh('r-0'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.network),
      ),
    );
    expect(waited, isFalse);
  });
}

class _Failing implements TokenRefresher {
  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      throw const ApiError(code: ApiErrorCode.network);
}
