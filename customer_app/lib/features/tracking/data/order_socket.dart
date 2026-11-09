import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:web_socket_channel/io.dart';

import '../domain/order_socket_event.dart';

/// One open WebSocket, as the order socket needs it. Production wraps
/// `web_socket_channel`; tests use a scripted fake.
abstract interface class WsConnection {
  /// Server frames; done when the socket closes.
  Stream<Object?> get frames;

  /// The close code, once [frames] is done.
  int? get closeCode;

  void send(String text);

  Future<void> close([int? code]);
}

/// Opens a socket to [uri]; throws when the handshake fails.
typedef WsConnector = Future<WsConnection> Function(Uri uri);

/// A token for the socket's `auth` message. [stale] is the token the
/// server just refused or that is about to expire: return a different
/// (refreshed) one. Null when signed out: the socket stops.
typedef WsTokenSource = Future<String?> Function({String? stale});

/// `web_socket_channel` over `dart:io`. No subprotocol is offered and the
/// token is never in the URL (`06 §4.1`): it goes in the first message.
Future<WsConnection> connectIoWebSocket(Uri uri) async {
  final channel = IOWebSocketChannel.connect(
    uri,
    connectTimeout: const Duration(seconds: 10),
  );
  await channel.ready;
  return _ChannelConnection(channel);
}

class _ChannelConnection implements WsConnection {
  _ChannelConnection(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<Object?> get frames => _channel.stream;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close([int? code]) async {
    await _channel.sink.close(code);
  }
}

/// `ws(s)://<origin>/ws/v1/orders/<id>/` from the API origin.
Uri orderSocketUri(Uri base, int orderId) => base.replace(
  scheme: base.scheme == 'https' ? 'wss' : 'ws',
  path: '/ws/v1/orders/$orderId/',
);

/// Close codes after which reconnecting cannot help (`06 §4.1`): not
/// allowed (4403) and not this user's order (4404). Polling carries on.
const terminalCloseCodes = {4403, 4404};

/// Reconnect delays: 1, 2, 4, 8, 16, then every 30 s.
const defaultWsBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 30),
];

/// The live feed of one order (`/ws/v1/orders/{id}/`, `06 §4`):
/// connects, authenticates with the first message, renews the token before
/// it expires, pings to keep the lease, and reconnects with backoff when
/// the socket drops. [live] is true only between `auth.ok` and a close, so
/// the screens poll `track/` whenever it is false.
class OrderSocket {
  OrderSocket({
    required this.orderId,
    required this.uri,
    required this._connect,
    required this._token,
    this.backoff = defaultWsBackoff,
    this.authTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 25),
    this.renewBefore = const Duration(seconds: 60),
    double Function()? jitter,
    DateTime Function()? now,
  }) : _jitter = jitter ?? math.Random().nextDouble,
       _now = now ?? DateTime.now;

  final int orderId;
  final Uri uri;
  final List<Duration> backoff;
  final Duration authTimeout;
  final Duration pingInterval;
  final Duration renewBefore;
  final WsConnector _connect;
  final WsTokenSource _token;
  final double Function() _jitter;
  final DateTime Function() _now;

  final _events = StreamController<OrderSocketEvent>.broadcast();
  final live = ValueNotifier<bool>(false);

  WsConnection? _conn;
  StreamSubscription<Object?>? _sub;
  Timer? _authTimer;
  Timer? _pingTimer;
  Timer? _renewTimer;
  Timer? _retryTimer;
  int _attempt = 0;
  String? _sentToken;
  String? _staleToken;
  bool _started = false;
  bool _stopped = false;

  /// Order events, in arrival order (broadcast).
  Stream<OrderSocketEvent> get events => _events.stream;

  /// Whether the socket stopped for good (signed out, 4403, 4404, disposed).
  bool get stopped => _stopped;

  /// How many connects have failed in a row (tests, diagnostics).
  @visibleForTesting
  int get attempt => _attempt;

  void start() {
    if (_started || _stopped) return;
    _started = true;
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_stopped) return;
    final String? token;
    try {
      token = await _token(stale: _staleToken);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    if (_stopped) return;
    if (token == null) {
      _stop();
      return;
    }
    _staleToken = null;
    final WsConnection conn;
    try {
      conn = await _connect(uri);
    } catch (_) {
      _scheduleRetry();
      return;
    }
    if (_stopped) {
      unawaited(conn.close(1000));
      return;
    }
    _conn = conn;
    _sub = conn.frames.listen(
      _onFrame,
      onError: (Object _) {},
      onDone: () => _onClosed(conn),
    );
    _sendAuth(token);
    _authTimer = Timer(authTimeout, () {
      if (!live.value && identical(_conn, conn)) unawaited(conn.close(1000));
    });
  }

  void _sendAuth(String token) {
    _sentToken = token;
    _conn?.send(jsonEncode({'type': 'auth', 'token': token}));
  }

  void _onFrame(Object? raw) {
    switch (parseWsFrame(raw)) {
      case WsAuthOk(:final expiresAt):
        _authTimer?.cancel();
        _attempt = 0;
        if (!live.value) {
          live.value = true;
          _pingTimer?.cancel();
          _pingTimer = Timer.periodic(
            pingInterval,
            (_) => _conn?.send('{"type":"ping"}'),
          );
        }
        _scheduleRenew(expiresAt);
      case WsEvent(:final event):
        if (event.orderId == orderId && !_events.isClosed) _events.add(event);
      case WsPong() || WsServerError() || WsIgnored():
        // Unknown and control messages are ignored (tolerant reader).
        break;
    }
  }

  void _scheduleRenew(DateTime? expiresAt) {
    _renewTimer?.cancel();
    if (expiresAt == null) return;
    var wait = expiresAt.difference(_now()) - renewBefore;
    if (wait.isNegative) wait = Duration.zero;
    _renewTimer = Timer(wait, () => unawaited(_renew()));
  }

  /// Sends a fresh token on the open socket before the current one expires.
  Future<void> _renew() async {
    final conn = _conn;
    if (conn == null || _stopped) return;
    String? token;
    try {
      token = await _token(stale: _sentToken);
    } catch (_) {
      token = null;
    }
    if (!identical(_conn, conn) || _stopped) return;
    if (token == null) {
      // Let it expire: the server closes with 4401 and the reconnect path
      // tries again (or stops when signed out).
      return;
    }
    _sendAuth(token);
  }

  void _onClosed(WsConnection conn) {
    if (!identical(_conn, conn)) return;
    _conn = null;
    unawaited(_sub?.cancel());
    _sub = null;
    _cancelTimers();
    final wasLive = live.value;
    live.value = false;
    if (_stopped) return;
    final code = conn.closeCode;
    if (code != null && terminalCloseCodes.contains(code)) {
      _stop();
      return;
    }
    // 4401 (refused or expired), or any close before `auth.ok` (including
    // our own auth-timeout close): the next attempt refreshes the token
    // first. 4429 (too many sockets) and the rest just back off.
    if (code == 4401 || !wasLive) _staleToken = _sentToken;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_stopped) return;
    final base = backoff[math.min(_attempt, backoff.length - 1)];
    _attempt++;
    // Up to +20% jitter, so a store's customers don't reconnect in step.
    final delay = base + base * (0.2 * _jitter());
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_open()));
  }

  void _cancelTimers() {
    _authTimer?.cancel();
    _pingTimer?.cancel();
    _renewTimer?.cancel();
  }

  void _stop() {
    _stopped = true;
    _retryTimer?.cancel();
    _cancelTimers();
    live.value = false;
  }

  /// Closes the socket and stops reconnecting.
  Future<void> dispose() async {
    _stop();
    final conn = _conn;
    final sub = _sub;
    _conn = null;
    _sub = null;
    live.dispose();
    unawaited(_events.close());
    if (conn != null) {
      try {
        await conn.close(1000);
      } catch (_) {}
    }
    await sub?.cancel();
  }
}

/// Opens order sockets. [DisabledOrderRealtime] where there is no socket
/// (fakes, tests, builds without orders): the screens just poll.
abstract interface class OrderRealtime {
  /// A started socket for [orderId], or null when realtime is off.
  OrderSocket? open(int orderId);
}

class DisabledOrderRealtime implements OrderRealtime {
  const DisabledOrderRealtime();

  @override
  OrderSocket? open(int orderId) => null;
}

/// The real sockets, authenticated with the [session]'s access token.
class WebSocketOrderRealtime implements OrderRealtime {
  WebSocketOrderRealtime({
    required this.apiBaseUrl,
    required this.session,
    this.connect = connectIoWebSocket,
  });

  final Uri apiBaseUrl;
  final SessionManager session;
  final WsConnector connect;

  @override
  OrderSocket? open(int orderId) => OrderSocket(
    orderId: orderId,
    uri: orderSocketUri(apiBaseUrl, orderId),
    connect: connect,
    token: sessionTokenSource(session),
  )..start();
}

/// The session's access token for the socket; with [stale] (refused or
/// expiring) a refreshed one, through the same single-flight refresh the
/// HTTP interceptor uses.
WsTokenSource sessionTokenSource(SessionManager session) =>
    ({String? stale}) async {
      await session.refreshDone;
      final current = session.accessToken;
      if (current == null) return null;
      if (stale == null || current != stale) return current;
      final outcome = await session.refreshAfterUnauthorized(
        session.tokenGeneration,
      );
      return switch (outcome) {
        RefreshSucceeded(:final tokens) => tokens.access,
        SessionEnded() => null,
        // Transient: keep trying with what we have (the retry backs off).
        RefreshFailed(:final error) => throw error,
      };
    };
