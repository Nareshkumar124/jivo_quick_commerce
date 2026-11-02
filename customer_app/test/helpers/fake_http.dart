import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

import 'test_config.dart';

/// A fake HTTP layer for the API repositories: records requests and answers
/// with `(status, jsonBody)`.
class FakeHttp implements HttpClientAdapter {
  FakeHttp(this.respond);

  final FutureOr<(int, Object?)> Function(RequestOptions request) respond;
  final List<RequestOptions> requests = [];

  /// The decoded JSON body of request [i].
  Map<String, Object?> body(int i) {
    final data = requests[i].data;
    return (data is String ? jsonDecode(data) : data) as Map<String, Object?>;
  }

  JivoApi api() => JivoApi(
    dio: createJivoDio(
      env: testEnv,
      clientInfo: testClientInfo,
      logRequests: false,
      httpClientAdapter: this,
    ),
    interceptors: const [],
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await respond(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
