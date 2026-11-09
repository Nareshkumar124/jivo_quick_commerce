import 'dart:async';
import 'dart:io';

import '../domain/socket_connection.dart';

/// `dart:io`'s WebSocket (Android only in v1, D-07). The client-info headers
/// go on the upgrade request; the JWT never does (it is the first message).
class IoSocketConnection implements SocketConnection {
  IoSocketConnection._(this._socket);

  final WebSocket _socket;

  static SocketConnector connector({
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 15),
  }) => (uri) async {
    final pending = WebSocket.connect(uri.toString(), headers: headers);
    try {
      return IoSocketConnection._(await pending.timeout(timeout));
    } on TimeoutException {
      // A socket that still connects after the timeout is closed, never
      // leaked (and a late failure is not left unhandled).
      unawaited(
        pending.then(
          (socket) => socket.close(1000),
          onError: (Object _) => null,
        ),
      );
      rethrow;
    }
  };

  @override
  Stream<Object?> get frames => _socket;

  @override
  void send(String text) => _socket.add(text);

  @override
  int? get closeCode => _socket.closeCode;

  @override
  Future<void> close([int code = 1000]) => _socket.close(code);
}
