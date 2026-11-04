import 'package:jivo_core/jivo_core.dart';

/// A [TokenRefresher] for a session that two isolates hold at once.
///
/// The rider app has two Dart isolates with their own copy of the session:
/// the UI and the location service, which uploads while the app is closed.
/// Refresh tokens rotate and work once (simplejwt `ROTATE_REFRESH_TOKENS` +
/// `BLACKLIST_AFTER_ROTATION`), so when one isolate refreshes, the other
/// one's refresh token is already revoked. A plain refresher would get 401
/// `TOKEN_INVALID` and jivo_core would end a perfectly good session.
///
/// Both isolates write the rotated pair to the same [TokenStore] (the
/// Android Keystore-backed secure storage). This wrapper reads it:
/// - **before** refreshing: if the stored pair already has a different
///   refresh token, the other isolate refreshed; use that pair, no network;
/// - **after** a `TOKEN_INVALID`: same check, for the race where both
///   refreshed at the same moment and the other one won.
///
/// Only when the store holds nothing newer is the rejection passed on (the
/// session really is over).
class StoreSyncedTokenRefresher implements TokenRefresher {
  StoreSyncedTokenRefresher({required this._inner, required this._store});

  final TokenRefresher _inner;
  final TokenStore _store;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final before = await _newerThan(refreshToken);
    if (before != null) return before;
    try {
      return await _inner.refresh(refreshToken);
    } on ApiError catch (error) {
      final rejected =
          error.statusCode == 401 && error.code == ApiErrorCode.tokenInvalid;
      if (rejected) {
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
