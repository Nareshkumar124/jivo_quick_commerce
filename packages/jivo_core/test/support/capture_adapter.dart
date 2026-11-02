import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A fake network layer: records every request and answers with [status] and
/// [body] (a JSON-encodable value or a raw string), or throws [error].
class CaptureAdapter implements HttpClientAdapter {
  CaptureAdapter({
    this.status = 200,
    this.body = const <String, Object>{},
    this.error,
  });

  final int status;
  final Object? body;
  final Object? error;
  final List<RequestOptions> requests = [];

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) throw error!;
    final isJson = body is! String;
    return ResponseBody.fromString(
      isJson ? jsonEncode(body) : body! as String,
      status,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : 'text/html',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
