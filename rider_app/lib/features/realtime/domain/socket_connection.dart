/// One open WebSocket, behind an interface so the client logic runs in unit
/// tests without a server.
abstract interface class SocketConnection {
  /// Incoming frames (text). Done when the socket closes.
  Stream<Object?> get frames;

  void send(String text);

  /// The close code once [frames] is done (4401, 4403, ...), else null.
  int? get closeCode;

  Future<void> close([int code = 1000]);
}

/// Opens [uri]. Throws when the connection cannot be made.
typedef SocketConnector = Future<SocketConnection> Function(Uri uri);
