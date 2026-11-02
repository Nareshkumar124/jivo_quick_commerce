import 'package:jivo_api/jivo_api.dart' show AppConfig;

/// `GET /api/v1/config/app/`: versions, maintenance, policy links,
/// `terms_version`, OTP settings and rider location intervals.
abstract interface class AppConfigRepository {
  /// Throws jivo_core's `ApiError` on failure.
  Future<AppConfig> fetch();
}
