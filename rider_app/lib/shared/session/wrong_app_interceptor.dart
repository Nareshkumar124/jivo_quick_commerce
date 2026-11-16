import 'dart:async';

import 'package:dio/dio.dart';
import 'package:jivo_core/jivo_core.dart';

import '../errors/wrong_app.dart';

/// DL-74: the rider API refuses tokens issued to the customer app (403,
/// see [WrongApp]). Such a session can never work here, so the rider is
/// signed out once and the login screen says to log in with the Jivo Rider
/// app ([onWrongApp]). The error still reaches the caller.
///
/// The rider app's own tokens are rider tokens: every request, OTP verify
/// and token refresh included, carries `X-App-Name: rider` (jivo_core's
/// client-info headers on every Dio this app builds), and OTP verify sends
/// `app: rider`.
class WrongAppInterceptor extends Interceptor {
  WrongAppInterceptor({required this.session, required this.onWrongApp});

  final SessionManager session;

  /// Runs before the session ends (remembers why, for the login screen).
  final void Function() onWrongApp;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        session.isSignedIn &&
        WrongApp.isWrongApp(ApiError.fromDioException(err))) {
      onWrongApp();
      unawaited(session.signOut(reason: SignOutReason.sessionExpired));
    }
    handler.next(err);
  }
}
