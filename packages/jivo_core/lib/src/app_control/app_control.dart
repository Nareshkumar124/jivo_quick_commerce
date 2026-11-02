import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/api_error.dart';

/// An app-wide state that blocks normal use (`03 §2.1`).
sealed class AppControlEvent {
  const AppControlEvent();
}

/// `426 APP_UPDATE_REQUIRED`: this app version is below the minimum.
/// Show the blocking "Update required" screen with [storeUrl].
final class AppUpdateRequired extends AppControlEvent {
  const AppUpdateRequired({
    this.minSupportedVersion,
    this.latestVersion,
    this.storeUrl,
  });

  /// From the error `details`. Null when the backend didn't send them.
  final String? minSupportedVersion;
  final String? latestVersion;
  final Uri? storeUrl;

  static AppUpdateRequired fromDetails(Map<String, Object?> details) {
    String? text(String key) {
      final value = details[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final url = text('store_url');
    return AppUpdateRequired(
      minSupportedVersion: text('min_supported_version'),
      latestVersion: text('latest_version'),
      storeUrl: url == null ? null : Uri.tryParse(url),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUpdateRequired &&
      other.minSupportedVersion == minSupportedVersion &&
      other.latestVersion == latestVersion &&
      other.storeUrl == storeUrl;

  @override
  int get hashCode => Object.hash(minSupportedVersion, latestVersion, storeUrl);

  @override
  String toString() =>
      'AppUpdateRequired(min: $minSupportedVersion, latest: $latestVersion)';
}

/// `503 MAINTENANCE`: show the full-screen maintenance message.
final class MaintenanceMode extends AppControlEvent {
  const MaintenanceMode({this.message});

  /// The maintenance text configured by ops (the envelope `message`). The
  /// contract says to show it; fall back to a localized default when null.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is MaintenanceMode && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'MaintenanceMode($message)';
}

/// Holds the current blocking state and broadcasts changes.
///
/// A [ChangeNotifier]: combine it with the session in go_router's
/// `refreshListenable` and redirect on [current]. [events] emits each event
/// as it is reported.
class AppControlSignals extends ChangeNotifier {
  final StreamController<AppControlEvent> _events =
      StreamController<AppControlEvent>.broadcast();

  AppControlEvent? _current;

  /// The active blocking state, or null for normal operation. A force update
  /// outranks maintenance.
  AppControlEvent? get current => _current;

  Stream<AppControlEvent> get events => _events.stream;

  /// Reports a force update. Also call it when `config/app` says the version
  /// is below `min_supported_version`.
  void reportUpdateRequired(AppUpdateRequired event) => _set(event);

  /// Reports maintenance mode. Also call it when `config/app` says
  /// `maintenance: true`.
  void reportMaintenance(MaintenanceMode event) {
    if (_current is AppUpdateRequired) return;
    _set(event);
  }

  /// Ends maintenance mode, e.g. after a successful `config/app` re-check.
  void clearMaintenance() {
    if (_current is! MaintenanceMode) return;
    _current = null;
    notifyListeners();
  }

  void _set(AppControlEvent event) {
    _events.add(event);
    if (_current == event) return;
    _current = event;
    notifyListeners();
  }

  @override
  void dispose() {
    _events.close();
    super.dispose();
  }
}

/// Reports `426 APP_UPDATE_REQUIRED` and `503 MAINTENANCE` responses from any
/// call to [signals]. The error still reaches the caller.
class AppControlInterceptor extends Interceptor {
  AppControlInterceptor(this.signals);

  final AppControlSignals signals;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final status = response?.statusCode;
    if (status == 426 || status == 503) {
      final error = ApiError.tryParseEnvelope(
        response?.data,
        statusCode: status,
      );
      if (status == 426) {
        // Any 426 means "update required", with or without an envelope.
        signals.reportUpdateRequired(
          AppUpdateRequired.fromDetails(error?.details ?? const {}),
        );
      } else if (error?.code == ApiErrorCode.maintenance) {
        // Other 503s (e.g. SERVICE_UNAVAILABLE) are outages, not maintenance.
        signals.reportMaintenance(
          MaintenanceMode(message: error?.serverMessage),
        );
      }
    }
    handler.next(err);
  }
}
