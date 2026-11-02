import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors/api_error.dart';
import 'token_refresher.dart';
import 'token_store.dart';

/// Whether a user is signed in. [unknown] until [SessionManager.restore] ran.
enum SessionStatus { unknown, signedIn, signedOut }

/// Why the session ended.
enum SignOutReason {
  /// The app called [SessionManager.signOut] (user logout, account deleted).
  userRequested,

  /// The refresh token was rejected (401 `TOKEN_INVALID`): expired after
  /// 30 days, revoked, or already used. Show "please log in again".
  sessionExpired,
}

/// Runs when the session ends, after the tokens are cleared and before
/// listeners hear [SessionStatus.signedOut]. Use it to clear app data
/// (cart cache, profile, push token registration, ...).
typedef SignOutHook = Future<void> Function(SignOutReason reason);

/// Result of [SessionManager.refreshAfterUnauthorized].
sealed class RefreshOutcome {
  const RefreshOutcome();
}

/// A valid pair is available (refreshed now, or by a concurrent caller).
final class RefreshSucceeded extends RefreshOutcome {
  const RefreshSucceeded(this.tokens);

  final AuthTokens tokens;
}

/// The session is over (signed out, or the refresh token was rejected).
final class SessionEnded extends RefreshOutcome {
  const SessionEnded();
}

/// The refresh failed for a transient reason (network, timeout, 5xx). The
/// session is kept; the caller's request fails with [error].
final class RefreshFailed extends RefreshOutcome {
  const RefreshFailed(this.error);

  final ApiError error;
}

/// Owns the signed-in state and the token pair (`02 §6`, `09 §3.1`).
///
/// - A [ChangeNotifier]: pass it as go_router's `refreshListenable` and
///   redirect on [status]. [statusStream] carries the same changes.
/// - [signIn] after `otp/verify`; [signOut] on logout.
/// - [refreshAfterUnauthorized] is single-flight: concurrent callers share
///   one refresh, because the backend revokes a refresh token once used.
class SessionManager extends ChangeNotifier {
  /// Named arguments: `store:` and `refresher:`.
  SessionManager({required this._store, required this._refresher});

  final TokenStore _store;
  final TokenRefresher _refresher;
  final List<SignOutHook> _signOutHooks = [];
  final StreamController<SessionStatus> _statusController =
      StreamController<SessionStatus>.broadcast();

  SessionStatus _status = SessionStatus.unknown;
  AuthTokens? _tokens;
  SignOutReason? _lastSignOutReason;
  Future<RefreshOutcome>? _refreshing;

  /// Bumped whenever the pair changes (restore, sign-in, refresh, sign-out).
  /// Requests remember the generation they were sent with instead of the
  /// token itself, so no token ends up in request metadata or logs.
  int _tokenGeneration = 0;

  SessionStatus get status => _status;

  bool get isSignedIn => _status == SessionStatus.signedIn;

  /// Emits every status change (broadcast).
  Stream<SessionStatus> get statusStream => _statusController.stream;

  /// Why the last session ended, or null if it hasn't ended.
  SignOutReason? get lastSignOutReason => _lastSignOutReason;

  /// The current access token, or null when signed out.
  String? get accessToken => _tokens?.access;

  /// The current refresh token, e.g. for `POST /auth/logout/` before
  /// [signOut]. Null when signed out.
  String? get refreshToken => _tokens?.refresh;

  /// Identifies the current pair; changes whenever the pair changes.
  int get tokenGeneration => _tokenGeneration;

  /// Completes when the refresh in flight (if any) has finished.
  Future<void> get refreshDone async {
    final pending = _refreshing;
    if (pending != null) await pending;
  }

  /// Loads the stored pair at startup. Call once before the first redirect.
  /// An unreadable store counts as signed out, so startup never gets stuck.
  Future<void> restore() async {
    AuthTokens? tokens;
    try {
      tokens = await _store.read();
    } catch (error, stack) {
      _report(error, stack, 'while reading stored tokens');
    }
    _setTokens(tokens);
    _setStatus(
      tokens == null ? SessionStatus.signedOut : SessionStatus.signedIn,
    );
  }

  /// Stores [tokens] and marks the user signed in. Throws if they can't be
  /// stored.
  Future<void> signIn(AuthTokens tokens) async {
    await _store.write(tokens);
    _setTokens(tokens);
    _lastSignOutReason = null;
    _setStatus(SessionStatus.signedIn);
  }

  /// Clears the tokens, runs the sign-out hooks, then marks the user signed
  /// out. Does not call the backend: call `POST /auth/logout/` with
  /// [refreshToken] first if the user logged out on purpose.
  Future<void> signOut({
    SignOutReason reason = SignOutReason.userRequested,
  }) async {
    final wasSignedOut = _status == SessionStatus.signedOut && _tokens == null;
    _setTokens(null);
    try {
      await _store.clear();
    } catch (error, stack) {
      _report(error, stack, 'while clearing stored tokens');
    }
    if (wasSignedOut) return;
    _lastSignOutReason = reason;
    for (final hook in List.of(_signOutHooks)) {
      try {
        await hook(reason);
      } catch (error, stack) {
        _report(error, stack, 'while running a sign-out hook');
      }
    }
    _setStatus(SessionStatus.signedOut);
  }

  /// Registers [hook] to clear app data on sign-out. Returns a function that
  /// removes it. Hooks may call the API: by then no token is attached.
  VoidCallback addSignOutHook(SignOutHook hook) {
    _signOutHooks.add(hook);
    return () => _signOutHooks.remove(hook);
  }

  /// Called after a request sent with token generation [failedGeneration]
  /// (see [tokenGeneration]) got 401.
  ///
  /// - If the pair changed since (another caller refreshed), returns it
  ///   without a new refresh.
  /// - Otherwise refreshes once; concurrent callers await the same refresh.
  /// - Only 401 `TOKEN_INVALID` from the refresh ends the session.
  Future<RefreshOutcome> refreshAfterUnauthorized(int failedGeneration) {
    final pending = _refreshing;
    if (pending != null) return pending;
    final current = _tokens;
    if (current == null) return Future.value(const SessionEnded());
    if (failedGeneration != _tokenGeneration) {
      return Future.value(RefreshSucceeded(current));
    }
    final refresh = _refresh(current);
    _refreshing = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshing, refresh)) _refreshing = null;
    });
  }

  Future<RefreshOutcome> _refresh(AuthTokens current) async {
    final generation = _tokenGeneration;
    final AuthTokens tokens;
    try {
      tokens = await _refresher.refresh(current.refresh);
    } on ApiError catch (error) {
      if (generation != _tokenGeneration) return _outcomeAfterChange();
      final rejected =
          error.statusCode == 401 && error.code == ApiErrorCode.tokenInvalid;
      if (!rejected) return RefreshFailed(error);
      // Release the single-flight slot first: sign-out hooks may call the
      // API, and requests wait for a refresh in flight before sending.
      _refreshing = null;
      await signOut(reason: SignOutReason.sessionExpired);
      return const SessionEnded();
    } catch (error) {
      if (generation != _tokenGeneration) return _outcomeAfterChange();
      return RefreshFailed(ApiError.from(error));
    }

    // Signed out or in again meanwhile: don't write stale tokens back.
    if (generation != _tokenGeneration) return _outcomeAfterChange();
    // The old refresh token is now revoked server-side, so the new pair is
    // used even if persisting it fails.
    _setTokens(tokens);
    try {
      await _store.write(tokens);
    } catch (error, stack) {
      _report(error, stack, 'while storing refreshed tokens');
    }
    return RefreshSucceeded(tokens);
  }

  RefreshOutcome _outcomeAfterChange() {
    final tokens = _tokens;
    return tokens == null ? const SessionEnded() : RefreshSucceeded(tokens);
  }

  void _setTokens(AuthTokens? tokens) {
    _tokens = tokens;
    _tokenGeneration++;
  }

  void _setStatus(SessionStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
    notifyListeners();
  }

  void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'jivo_core',
        context: ErrorDescription(context),
      ),
    );
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
