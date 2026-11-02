import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Starts Sentry crash reporting, then runs [appRunner].
///
/// When [dsn] is null or empty, Sentry stays disabled and [appRunner] runs
/// directly. PII is not sent by default.
Future<void> runWithSentry({
  required String? dsn,
  required String environment,
  required FutureOr<void> Function() appRunner,
  String? release,
  double tracesSampleRate = 0,
}) async {
  if (dsn == null || dsn.trim().isEmpty) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = dsn
      ..environment = environment
      ..release = release
      ..tracesSampleRate = tracesSampleRate
      ..sendDefaultPii = false;
  }, appRunner: appRunner);
}
