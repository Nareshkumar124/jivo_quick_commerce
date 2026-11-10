import 'dart:async';
import 'dart:convert';

import 'package:rider_app/features/realtime/domain/socket_connection.dart';

/// One fake socket: records what the app sends; the test pushes frames and
/// closes it with a code.
class FakeSocket implements SocketConnection {
  final _frames = StreamController<Object?>();
  final List<Map<String, Object?>> sent = [];
  int? _closeCode;
  bool closedByApp = false;

  @override
  Stream<Object?> get frames => _frames.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  void send(String text) =>
      sent.add((jsonDecode(text) as Map).cast<String, Object?>());

  @override
  Future<void> close([int code = 1000]) async {
    closedByApp = true;
    _closeCode ??= code;
    if (!_frames.isClosed) await _frames.close();
  }

  void receive(Map<String, Object?> message) =>
      _frames.add(jsonEncode(message));

  void authOk({String expiresAt = '2026-11-02T06:15:00Z'}) => receive({
    'type': 'auth.ok',
    'data': {'user_id': 1, 'expires_at': expiresAt},
    'sent_at': '2026-11-02T06:00:00Z',
  });

  /// The server closes with [code].
  void serverClose(int code) {
    _closeCode = code;
    unawaited(_frames.close());
  }
}

/// Hands out [FakeSocket]s; [failNext] makes the next connect throw.
class FakeConnector {
  final List<FakeSocket> sockets = [];
  final List<Uri> uris = [];
  int failNext = 0;

  FakeSocket get last => sockets.last;

  Future<SocketConnection> call(Uri uri) async {
    uris.add(uri);
    if (failNext > 0) {
      failNext--;
      throw Exception('no network');
    }
    final socket = FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

Map<String, Object?> offerNewMessage({
  int id = 9001,
  String expiresAt = '2026-11-02T06:00:30Z',
}) => {
  'type': 'offer.new',
  'data': {
    'id': id,
    'task_id': 7001,
    'store_name': 'Jivo Sector 14',
    'drop_locality': 'Sector 21, Gurugram',
    'distance_km': '2.40',
    'payment_type': 'COD',
    'cod_amount': '498.00',
    'estimated_payout': '42.00',
    'item_count': 3,
    'offered_at': '2026-11-02T06:00:00Z',
    'expires_at': expiresAt,
  },
  'sent_at': '2026-11-02T06:00:00.120000Z',
};
