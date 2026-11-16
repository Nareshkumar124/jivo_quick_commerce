import 'package:dio/dio.dart';
import 'package:jivo_core/jivo_core.dart';

/// Tells `NetworkHealth` (CA-02) whether each request reached the server:
/// a response (any status) is an answer; a network error or a timeout is a
/// failure; a cancelled request is neither.
class NetworkHealthInterceptor extends Interceptor {
  NetworkHealthInterceptor({required this.onFailed, required this.onAnswered});

  final void Function() onFailed;
  final void Function() onAnswered;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    onAnswered();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      onAnswered();
    } else {
      switch (ApiError.fromDioException(err).code) {
        case ApiErrorCode.network || ApiErrorCode.timeout:
          onFailed();
        case _:
          break;
      }
    }
    handler.next(err);
  }
}
