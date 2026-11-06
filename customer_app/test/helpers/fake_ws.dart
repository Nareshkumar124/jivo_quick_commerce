import 'dart:async';
import 'dart:convert';

import 'package:customer_app/features/tracking/data/order_socket.dart';

/// A scripted socket: the test plays the server.
class FakeWsConnection implements WsConnection {
  FakeWsConnection(this.uri);

  final Uri uri;
  final _frames = StreamController<Object?>();
  final List<Map<String, Object?>> sent = [];
  int? _closeCode;
  bool closedByClient = false;

  @override
  Stream<Object?> get frames => _frames.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void send(String text) => sent.add(jsonDecode(text) as Map<String, Object?>);

  @override
  Future<void> close([int? code]) async {
    closedByClient = true;
    _closeCode ??= code ?? 1005;
    if (!_frames.isClosed) await _frames.close();
  }

  /// A server message `{"type", "data", "sent_at"}`.
  void push(String type, [Map<String, Object?> data = const {}]) => _frames.add(
    jsonEncode({'type': type, 'data': data, 'sent_at': '2026-11-10T09:40:00Z'}),
  );

  void pushRaw(Object? raw) => _frames.add(raw);

  void authOk({String? expiresAt}) =>
      push('auth.ok', {'user_id': 812, 'expires_at': expiresAt});

  /// The server closes the socket with [code].
  void serverClose(int code) {
    _closeCode = code;
    unawaited(_frames.close());
  }
}

/// Connects to [FakeWsConnection]s, or fails while [failConnects] > 0.
class FakeWsServer {
  final List<FakeWsConnection> connections = [];
  int failConnects = 0;

  FakeWsConnection get last => connections.last;

  Future<WsConnection> connect(Uri uri) async {
    if (failConnects > 0) {
      failConnects--;
      throw const SocketLikeException();
    }
    final conn = FakeWsConnection(uri);
    connections.add(conn);
    return conn;
  }
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}

/// Order sockets on a [FakeWsServer] with a fixed token, no jitter.
class FakeOrderRealtime implements OrderRealtime {
  FakeOrderRealtime({this._token = 'a1'});

  final String _token;
  final server = FakeWsServer();
  final Map<int, OrderSocket> sockets = {};

  @override
  OrderSocket? open(int orderId) {
    final socket = OrderSocket(
      orderId: orderId,
      uri: Uri.parse('ws://test/ws/v1/orders/$orderId/'),
      connect: server.connect,
      token: ({String? stale}) async => _token,
      jitter: () => 0,
    )..start();
    sockets[orderId] = socket;
    return socket;
  }
}

Map<String, Object?> statusData(int orderId, String status, {String? eta}) => {
  'order_id': orderId,
  'order_number': 'JV-261110-${orderId.toString().padLeft(6, '0')}',
  'store_id': 1,
  'status': status,
  'payment_status': 'PAID',
  'eta_at': eta,
  'updated_at': '2026-11-10T09:41:04.880000Z',
};
