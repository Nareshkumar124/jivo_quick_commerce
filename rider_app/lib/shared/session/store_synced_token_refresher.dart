import 'package:jivo_core/jivo_core.dart';

Future<void> _sleep(Duration d) => Future<void>.delayed(d);

/// A [TokenRefresher] for a session that two isolates hold at once.
///
/// The rider app has two Dart isolates with their own copy of the session:
/// the UI and the location service, which uploads while the app is closed.
/// Refresh tokens rotate and work once (simplejwt `ROTATE_REFRESH_TOKENS` +
/// `BLACKLIST_AFTER_ROTATION`), so when one isolate refreshes, the other
/// one's refresh token is already revoked. A plain refresher would get 401
/// `TOKEN_INVALID` and jivo_core would end a perfectly good session.
///
/// Both isolates write the rotated pair to the same [TokenStore]. On
/// Android that is `flutter_secure_storage`, which reads
/// `SharedPreferences` on every call; the service runs in the app's process,
/// so both engines share one in-process preferences map and a read sees the
/// other isolate's completed write. There is no Dart-side cache to bypass.
///
/// This wrapper reads the store:
/// - **before** refreshing: if the stored pair already has a different
///   refresh token, the other isolate refreshed; use that pair, no network;
/// - **after** a `TOKEN_INVALID`: again, several times over about 1.5 s
///   ([retryDelays]), because the winner of a simultaneous refresh may still
///   be writing its new pair when the loser's rejection arrives.
///
/// Only when the store still holds nothing newer is the rejection passed on.
/// Even then, [GuardedTokenStore] keeps the sign-out from wiping a pair the
/// other isolate wrote meanwhile.
class StoreSyncedTokenRefresher implements TokenRefresher {
  StoreSyncedTokenRefresher({
    required this._inner,
    required this._store,
    this.retryDelays = defaultRetryDelays,
    Future<void> Function(Duration) sleep = _sleep,
  }) : _wait = sleep;

  /// About 1.5 s in total.
  static const defaultRetryDelays = [
    Duration(milliseconds: 100),
    Duration(milliseconds: 200),
    Duration(milliseconds: 400),
    Duration(milliseconds: 800),
  ];

  final TokenRefresher _inner;
  final TokenStore _store;
  final List<Duration> retryDelays;
  final Future<void> Function(Duration) _wait;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final before = await _newerThan(refreshToken);
    if (before != null) return before;
    try {
      return await _inner.refresh(refreshToken);
    } on ApiError catch (error) {
      final rejected =
          error.statusCode == 401 && error.code == ApiErrorCode.tokenInvalid;
      if (!rejected) rethrow;
      for (final delay in [Duration.zero, ...retryDelays]) {
        if (delay > Duration.zero) await _wait(delay);
        final after = await _newerThan(refreshToken);
        if (after != null) return after;
      }
      rethrow;
    }
  }

  /// The stored pair if another isolate rotated [refreshToken], else null.
  Future<AuthTokens?> _newerThan(String refreshToken) async {
    try {
      final stored = await _store.read();
      if (stored != null && stored.refresh != refreshToken) return stored;
    } on Object {
      // Unreadable store: behave like a plain refresher.
    }
    return null;
  }
}

/// A [TokenStore] shared by two isolates, whose [clear] never wipes a pair
/// this isolate has not seen.
///
/// jivo_core's `SessionManager` clears the store when its session ends
/// (logout, or a refresh rejected for good). If the other isolate wrote a
/// newer pair in the meantime (it won a refresh race), clearing would log
/// out both. So [clear] re-reads first and only clears when the stored pair
/// is the one this isolate last read or wrote (or nothing). A deliberate
/// logout must always clear, even if the UI holds an older pair than the
/// service stored: the app calls [clearUnconditionally] for it.
class GuardedTokenStore implements TokenStore {
  GuardedTokenStore(this._inner);

  final TokenStore _inner;
  AuthTokens? _lastKnown;

  @override
  Future<AuthTokens?> read() async => _lastKnown = await _inner.read();

  @override
  Future<void> write(AuthTokens tokens) async {
    await _inner.write(tokens);
    _lastKnown = tokens;
  }

  @override
  Future<void> clear() async {
    AuthTokens? stored;
    try {
      stored = await _inner.read();
    } on Object {
      stored = null;
    }
    if (stored != null && _lastKnown != null && stored != _lastKnown) {
      // Another isolate stored a newer pair: its session is fine.
      return;
    }
    await _inner.clear();
    _lastKnown = null;
  }

  /// For a deliberate logout: removes whatever is stored.
  Future<void> clearUnconditionally() async {
    await _inner.clear();
    _lastKnown = null;
  }
}
