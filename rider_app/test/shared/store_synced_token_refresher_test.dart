import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/shared/session/store_synced_token_refresher.dart';

/// Rotates once per refresh token, like simplejwt with
/// BLACKLIST_AFTER_ROTATION.
class _RotatingServer implements TokenRefresher {
  final used = <String>{};
  int calls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls++;
    if (!used.add(refreshToken)) {
      throw const ApiError(code: ApiErrorCode.tokenInvalid, statusCode: 401);
    }
    return AuthTokens(access: 'a-$calls', refresh: 'r-$calls');
  }
}

void main() {
  const start = AuthTokens(access: 'a-0', refresh: 'r-0');

  test(
    'the other isolate already rotated: use the stored pair, no request',
    () async {
      final store = InMemoryTokenStore();
      await store.write(const AuthTokens(access: 'a-x', refresh: 'r-x'));
      final server = _RotatingServer();
      final refresher = StoreSyncedTokenRefresher(inner: server, store: store);

      final tokens = await refresher.refresh('r-0');
      expect(tokens.refresh, 'r-x');
      expect(server.calls, 0);
    },
  );

  test('both isolates refresh at once: the loser adopts the winner\'s pair '
      'instead of ending the session', () async {
    final store = InMemoryTokenStore();
    await store.write(start);
    final server = _RotatingServer();
    // Two sessions (UI and location service) over one secure store.
    final ui = SessionManager(
      store: store,
      refresher: StoreSyncedTokenRefresher(inner: server, store: store),
    );
    final service = SessionManager(
      store: store,
      refresher: StoreSyncedTokenRefresher(inner: server, store: store),
    );
    await ui.restore();
    await service.restore();

    final serviceResult = await service.refreshAfterUnauthorized(
      service.tokenGeneration,
    );
    expect(serviceResult, isA<RefreshSucceeded>());

    // The UI still holds r-0, which the server has revoked.
    final uiResult = await ui.refreshAfterUnauthorized(ui.tokenGeneration);
    expect(uiResult, isA<RefreshSucceeded>());
    expect(ui.isSignedIn, isTrue);
    expect(ui.refreshToken, service.refreshToken);
  });

  test(
    'a rejection with nothing newer in the store still ends the session',
    () async {
      final store = InMemoryTokenStore();
      await store.write(start);
      final server = _RotatingServer()..used.add('r-0');
      final session = SessionManager(
        store: store,
        refresher: StoreSyncedTokenRefresher(inner: server, store: store),
      );
      await session.restore();

      final result = await session.refreshAfterUnauthorized(
        session.tokenGeneration,
      );
      expect(result, isA<SessionEnded>());
      expect(session.isSignedIn, isFalse);
    },
  );

  test('a transient failure is passed on unchanged', () async {
    final store = InMemoryTokenStore();
    await store.write(start);
    final refresher = StoreSyncedTokenRefresher(
      inner: _Failing(),
      store: store,
    );
    expect(
      () => refresher.refresh('r-0'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.network),
      ),
    );
  });
}

class _Failing implements TokenRefresher {
  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      throw const ApiError(code: ApiErrorCode.network);
}
