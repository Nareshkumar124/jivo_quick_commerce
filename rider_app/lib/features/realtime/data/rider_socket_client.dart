import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../location/domain/backoff.dart';
import '../domain/socket_connection.dart';
import 'rider_socket_message.dart';

enum RiderSocketStatus {
  /// Not running, or waiting to reconnect (polling covers it).
  disconnected,

  /// Connecting, or connected and waiting for `auth.ok`.
  connecting,

  /// `auth.ok` received: live events flow.
  connected,
}

/// Close codes of 06 §4.1.
abstract final class SocketCloseCode {
  static const notAuthFirst = 4400;
  static const unauthorized = 4401;
  static const forbidden = 4403;
  static const authTimeout = 4408;
  static const tooManySockets = 4429;
}

/// The rider socket `/ws/v1/rider/` (06 §4): connects, sends the JWT in the
/// first message (never in the URL), keeps the socket alive with app pings,
/// re-authenticates before the token's `expires_at`, and reconnects with
/// backoff after any close. While it is not [RiderSocketStatus.connected]
/// the app polls (`GET /rider/offers/current/`).
///
/// [accessToken] returns the session's current access token; [refreshToken]
/// refreshes it (single-flight in jivo_core) and returns the new one, or
/// null when the session ended.
class RiderSocketClient {
  RiderSocketClient({
    required this.uri,
    required this._connect,
    required this._accessToken,
    required this._refreshToken,
    Backoff Function()? backoff,
    DateTime Function()? clock,
    this.pingInterval = const Duration(seconds: 25),
    this.pongTimeout = const Duration(seconds: 10),
    this.authTimeout = const Duration(seconds: 10),
    this.reauthLead = const Duration(seconds: 60),
  }) : _backoff =
           (backoff ??
           () => Backoff(
             initial: const Duration(seconds: 2),
             max: const Duration(minutes: 1),
           ))(),
       _clock = clock ?? DateTime.now;

  final Uri uri;
  final SocketConnector _connect;
  final String? Function() _accessToken;
  final Future<String?> Function() _refreshToken;
  final Backoff _backoff;
  final DateTime Function() _clock;
  final Duration pingInterval;
  final Duration pongTimeout;
  final Duration authTimeout;
  final Duration reauthLead;

  /// After 4403 (not an active rider, wrong app) the server will say the
  /// same again soon: wait at least this long.
  static const forbiddenWait = Duration(minutes: 1);

  final _messages = StreamController<RiderSocketMessage>.broadcast();
  final _statuses = StreamController<RiderSocketStatus>.broadcast();

  /// Server events (offers, task, cash); control messages are handled here.
  Stream<RiderSocketMessage> get messages => _messages.stream;

  Stream<RiderSocketStatus> get statuses => _statuses.stream;

  RiderSocketStatus get status => _status;
  RiderSocketStatus _status = RiderSocketStatus.disconnected;

  bool _running = false;
  bool get isRunning => _running;

  /// Bumped on every connect attempt and on stop, so callbacks of an older
  /// socket never act on the current one.
  int _attempt = 0;
  SocketConnection? _connection;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnect;
  Timer? _ping;
  Timer? _pongDeadline;
  Timer? _authDeadline;
  Timer? _reauth;
  String? _sentToken;
  bool _refreshFirst = false;
  int _unauthorizedCloses = 0;

  /// Consecutive 4401 closes (each after a token refresh) before the client
  /// gives up: the session is most likely over, and jivo_core's session-end
  /// handling signs the rider out (which stops the socket for good).
  static const maxUnauthorizedCloses = 3;

  /// The client stopped itself after [maxUnauthorizedCloses] 4401 closes.
  bool get gaveUpUnauthorized => _gaveUpUnauthorized;
  bool _gaveUpUnauthorized = false;

  /// Connects (if not running yet). Safe to call repeatedly.
  void start() {
    if (_running) return;
    _running = true;
    _unauthorizedCloses = 0;
    _gaveUpUnauthorized = false;
    _backoff.reset();
    unawaited(_open());
  }

  /// Closes the socket and stops reconnecting (offline, signed out).
  Future<void> stop() async {
    if (!_running && _connection == null) return;
    _running = false;
    _attempt++;
    _reconnect?.cancel();
    _reconnect = null;
    _teardown(closeWith: 1000);
    _setStatus(RiderSocketStatus.disconnected);
  }

  Future<void> dispose() async {
    await stop();
    await _messages.close();
    await _statuses.close();
  }

  Future<void> _open() async {
    final attempt = ++_attempt;
    _setStatus(RiderSocketStatus.connecting);
    String? token;
    try {
      token = _refreshFirst ? await _refreshToken() : _accessToken();
    } on Object catch (error) {
      debugPrint('RiderSocket: token unavailable: ${error.runtimeType}');
    }
    _refreshFirst = false;
    if (attempt != _attempt) return;
    if (token == null) {
      _retryLater();
      return;
    }
    final SocketConnection connection;
    try {
      connection = await _connect(uri);
    } on Object catch (error) {
      if (attempt != _attempt) return;
      debugPrint('RiderSocket: connect failed: ${error.runtimeType}');
      _retryLater();
      return;
    }
    if (attempt != _attempt) {
      unawaited(connection.close());
      return;
    }
    _connection = connection;
    _subscription = connection.frames.listen(
      (frame) => _onFrame(attempt, frame),
      onError: (Object error) =>
          debugPrint('RiderSocket: stream error: ${error.runtimeType}'),
      onDone: () => _onClosed(attempt, connection.closeCode),
      cancelOnError: false,
    );
    _sendAuth(token);
    _armAuthDeadline(attempt);
  }

  /// Every auth message must be answered by `auth.ok` in [authTimeout], or
  /// the socket is dropped (and the offer poll takes over).
  void _armAuthDeadline(int attempt) {
    _authDeadline?.cancel();
    _authDeadline = Timer(authTimeout, () {
      if (attempt != _attempt) return;
      debugPrint('RiderSocket: no auth.ok in time');
      _dropAndRetry(attempt);
    });
  }

  void _sendAuth(String token) {
    _sentToken = token;
    _send({'type': 'auth', 'token': token});
  }

  void _send(Map<String, Object?> message) {
    try {
      _connection?.send(jsonEncode(message));
    } on Object catch (error) {
      debugPrint('RiderSocket: send failed: ${error.runtimeType}');
    }
  }

  void _onFrame(int attempt, Object? frame) {
    if (attempt != _attempt) return;
    final message = parseRiderSocketMessage(frame);
    switch (message) {
      case SocketAuthOk(:final expiresAt):
        _authDeadline?.cancel();
        _authDeadline = null;
        _unauthorizedCloses = 0;
        _backoff.reset();
        _scheduleReauth(attempt, expiresAt);
        _startPings(attempt);
        _setStatus(RiderSocketStatus.connected);
      case SocketPong():
        _pongDeadline?.cancel();
        _pongDeadline = null;
      case SocketError(:final code):
        debugPrint('RiderSocket: server error $code');
      case UnknownSocketMessage(:final type):
        debugPrint('RiderSocket: ignored message type $type');
      case SocketOfferNew() ||
          SocketOfferEnded() ||
          SocketTaskUpdated() ||
          SocketCashUpdated():
        if (!_messages.isClosed) _messages.add(message);
    }
  }

  void _startPings(int attempt) {
    _ping?.cancel();
    _ping = Timer.periodic(pingInterval, (_) {
      if (attempt != _attempt) return;
      _send({'type': 'ping'});
      _pongDeadline ??= Timer(pongTimeout, () {
        if (attempt != _attempt) return;
        // A half-open socket (the network changed): reconnect.
        debugPrint('RiderSocket: no pong; reconnecting');
        _dropAndRetry(attempt);
      });
    });
  }

  /// Sends a fresh token before the current one expires (else 4401).
  void _scheduleReauth(int attempt, DateTime? expiresAt) {
    _reauth?.cancel();
    _reauth = null;
    if (expiresAt == null) return;
    var wait = expiresAt.difference(_clock().toUtc()) - reauthLead;
    if (wait < Duration.zero) wait = Duration.zero;
    _reauth = Timer(wait, () => unawaited(_reauthenticate(attempt)));
  }

  Future<void> _reauthenticate(int attempt) async {
    String? token = _accessToken();
    // Dio may have refreshed the pair already; otherwise refresh now.
    if (token == null || token == _sentToken) {
      try {
        token = await _refreshToken();
      } on Object catch (error) {
        debugPrint('RiderSocket: refresh failed: ${error.runtimeType}');
        token = null;
      }
    }
    if (attempt != _attempt) return;
    if (token == null) {
      // No fresh token: don't wait for the server's 4401 at expiry. Drop
      // now so the app polls, and reconnect with backoff.
      debugPrint('RiderSocket: re-auth without a token; reconnecting');
      _dropAndRetry(attempt);
      return;
    }
    _sendAuth(token);
    _armAuthDeadline(attempt);
  }

  void _onClosed(int attempt, int? code) {
    if (attempt != _attempt) return;
    debugPrint('RiderSocket: closed ($code)');
    _teardown();
    _setStatus(RiderSocketStatus.disconnected);
    if (!_running) return;
    Duration? hint;
    switch (code) {
      case SocketCloseCode.unauthorized:
        _unauthorizedCloses++;
        if (_unauthorizedCloses >= maxUnauthorizedCloses) {
          debugPrint('RiderSocket: refused $_unauthorizedCloses times; stop');
          _gaveUpUnauthorized = true;
          _running = false;
          _reconnect?.cancel();
          _reconnect = null;
          return;
        }
        _refreshFirst = true;
      case SocketCloseCode.forbidden:
        hint = forbiddenWait;
      case SocketCloseCode.tooManySockets:
        hint = const Duration(seconds: 30);
    }
    _retryLater(hint: hint);
  }

  void _dropAndRetry(int attempt) {
    if (attempt != _attempt) return;
    _attempt++;
    _teardown(closeWith: 1000);
    _setStatus(RiderSocketStatus.disconnected);
    if (_running) _retryLater();
  }

  void _retryLater({Duration? hint}) {
    if (!_running) return;
    _setStatus(RiderSocketStatus.disconnected);
    _reconnect?.cancel();
    final wait = _backoff.fail(serverHint: hint);
    _reconnect = Timer(wait, () {
      _reconnect = null;
      if (_running) unawaited(_open());
    });
  }

  /// Drops the current socket. Nothing here waits on the network: a close
  /// handshake on a dead connection must not hold up the reconnect.
  void _teardown({int? closeWith}) {
    for (final timer in [_ping, _pongDeadline, _authDeadline, _reauth]) {
      timer?.cancel();
    }
    _ping = _pongDeadline = _authDeadline = _reauth = null;
    final subscription = _subscription;
    final connection = _connection;
    _subscription = null;
    _connection = null;
    _sentToken = null;
    unawaited(subscription?.cancel());
    if (closeWith != null && connection != null) {
      unawaited(
        connection
            .close(closeWith)
            .catchError(
              (Object error) =>
                  debugPrint('RiderSocket: close failed: ${error.runtimeType}'),
            ),
      );
    }
  }

  void _setStatus(RiderSocketStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }
}
