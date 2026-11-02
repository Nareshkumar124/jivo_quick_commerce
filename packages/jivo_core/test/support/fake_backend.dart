import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A fake HTTP layer. [respond] gets each request and returns
/// `(status, jsonBody)`, or throws to simulate a transport failure.
class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.respond);

  final FutureOr<(int, Object?)> Function(RequestOptions request) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The `Authorization` header of [request], whatever its case.
String? authorizationOf(RequestOptions request) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') return '${entry.value}';
  }
  return null;
}

Map<String, Object?> envelope(
  String code, {
  String message = 'msg',
  Map<String, Object?> details = const {},
}) => {
  'error': {'code': code, 'message': message, 'details': details},
};
