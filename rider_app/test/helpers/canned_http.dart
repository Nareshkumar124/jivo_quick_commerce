import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

/// One canned answer: a status and a JSON body, or a connection error.
class Canned {
  const Canned(this.status, [this.body]) : connectionError = false;
  const Canned.offline() : status = 0, body = null, connectionError = true;

  final int status;
  final Object? body;
  final bool connectionError;
}

/// Records requests and answers them from [answers] (by path).
class CannedAdapter implements HttpClientAdapter {
  final answers = <String, Canned>{};
  final requests = <RequestOptions>[];
  final bodies = <String, Object?>{};

  /// The JSON body sent to [path], decoded.
  Map<String, dynamic> jsonBody(String path) {
    final data = bodies[path];
    return (data is String ? jsonDecode(data) : data) as Map<String, dynamic>;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies[options.path] = options.data;
    final canned = answers[options.path];
    if (canned == null || canned.connectionError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      canned.body == null ? '' : jsonEncode(canned.body),
      canned.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The generated client on a Dio whose network is [adapter].
JivoApi cannedApi(CannedAdapter adapter) {
  final dio = createJivoDio(
    env: AppEnv(
      flavor: Flavor.dev,
      apiBaseUrl: Uri.parse('http://localhost:8001'),
    ),
    clientInfo: const ClientInfo(
      appName: 'rider',
      appVersion: '1.0.0',
      platform: 'android',
    ),
    httpClientAdapter: adapter,
    logRequests: false,
  );
  return JivoApi(dio: dio, interceptors: const []);
}

const locationSettingsJson = {
  'active_interval_seconds': 10,
  'idle_interval_seconds': 30,
  'active_sample_seconds': 5,
  'idle_sample_seconds': 20,
  'max_batch': 40,
};

Map<String, Object?> errorBody(
  String code, [
  Map<String, Object?> details = const {},
]) => {
  'error': {'code': code, 'message': 'x', 'details': details},
};
