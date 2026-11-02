import 'package:flutter/foundation.dart';

/// The build flavor an app was launched with. Each app has one entry point
/// per flavor (`main_dev.dart`, `main_staging.dart`, `main_prod.dart`).
enum Flavor { dev, staging, prod }

/// Thrown at startup when the per-flavor configuration is missing or invalid.
class EnvConfigException implements Exception {
  const EnvConfigException(this.message);

  final String message;

  @override
  String toString() => 'EnvConfigException: $message';
}

/// Runtime configuration for one flavor.
///
/// Values come from `--dart-define` (or `--dart-define-from-file`), never from
/// source code. Supported keys:
///
/// | Key            | Meaning                                                |
/// |----------------|--------------------------------------------------------|
/// | `API_BASE_URL` | Backend origin, e.g. `https://api.example.in`. The API  |
/// |                | paths themselves include `/api/v1/`. Optional for dev   |
/// |                | (defaults to [devDefaultApiBaseUrl]), required otherwise.|
/// | `SENTRY_DSN`   | Sentry DSN. Empty or absent disables Sentry.           |
/// | `FAKE_API`     | `true` swaps in fake repositories (dev/staging only;   |
/// |                | always ignored for [Flavor.prod]).                     |
@immutable
class AppEnv {
  const AppEnv({
    required this.flavor,
    required this.apiBaseUrl,
    this.sentryDsn,
    this.useFakeApi = false,
  });

  /// Reads the configuration compiled in with `--dart-define`.
  factory AppEnv.fromEnvironment(Flavor flavor) => AppEnv.resolve(
    flavor: flavor,
    apiBaseUrl: const String.fromEnvironment(apiBaseUrlKey),
    sentryDsn: const String.fromEnvironment(sentryDsnKey),
    useFakeApi: const bool.fromEnvironment(useFakeApiKey),
  );

  /// Validates raw values and applies the per-flavor defaults.
  ///
  /// Throws [EnvConfigException] when `API_BASE_URL` is missing for a non-dev
  /// flavor, is not an absolute http(s) URL, or is not https for prod.
  factory AppEnv.resolve({
    required Flavor flavor,
    String apiBaseUrl = '',
    String sentryDsn = '',
    bool useFakeApi = false,
  }) {
    final trimmedUrl = apiBaseUrl.trim();
    final rawUrl = trimmedUrl.isNotEmpty
        ? trimmedUrl
        : (flavor == Flavor.dev ? devDefaultApiBaseUrl : null);
    if (rawUrl == null) {
      throw EnvConfigException(
        '$apiBaseUrlKey is required for the ${flavor.name} flavor. '
        'Pass --dart-define=$apiBaseUrlKey=https://...',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    final isHttp =
        uri != null && (uri.isScheme('http') || uri.isScheme('https'));
    if (!isHttp || uri.host.isEmpty) {
      throw EnvConfigException('$apiBaseUrlKey is not an http(s) URL: $rawUrl');
    }
    if (flavor == Flavor.prod && !uri.isScheme('https')) {
      throw EnvConfigException(
        '$apiBaseUrlKey must use https for prod: $rawUrl',
      );
    }

    final dsn = sentryDsn.trim();
    return AppEnv(
      flavor: flavor,
      apiBaseUrl: _withoutTrailingSlash(uri),
      sentryDsn: dsn.isEmpty ? null : dsn,
      useFakeApi: flavor != Flavor.prod && useFakeApi,
    );
  }

  static const apiBaseUrlKey = 'API_BASE_URL';
  static const sentryDsnKey = 'SENTRY_DSN';
  static const useFakeApiKey = 'FAKE_API';

  /// The local backend as seen from the Android emulator (host port 8001).
  static const devDefaultApiBaseUrl = 'http://10.0.2.2:8001';

  final Flavor flavor;

  /// Backend origin without a trailing slash. API paths include `/api/v1/`.
  final Uri apiBaseUrl;

  /// Sentry DSN, or null when crash reporting is disabled.
  final String? sentryDsn;

  /// Whether fake repositories replace network calls. Never true for prod.
  final bool useFakeApi;

  bool get isProd => flavor == Flavor.prod;

  /// The environment name reported to Sentry and analytics.
  String get environmentName => flavor.name;

  static Uri _withoutTrailingSlash(Uri uri) {
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path);
  }

  @override
  bool operator ==(Object other) =>
      other is AppEnv &&
      other.flavor == flavor &&
      other.apiBaseUrl == apiBaseUrl &&
      other.sentryDsn == sentryDsn &&
      other.useFakeApi == useFakeApi;

  @override
  int get hashCode => Object.hash(flavor, apiBaseUrl, sentryDsn, useFakeApi);

  @override
  String toString() =>
      'AppEnv(${flavor.name}, $apiBaseUrl, sentry: ${sentryDsn != null}, fakeApi: $useFakeApi)';
}
