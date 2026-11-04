import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../domain/launch_config.dart';

abstract interface class ConfigRepository {
  /// Throws [ApiError].
  Future<LaunchConfig> fetch();
}

class ApiConfigRepository implements ConfigRepository {
  const ApiConfigRepository(this._api);

  final JivoApi _api;

  @override
  Future<LaunchConfig> fetch() async {
    try {
      final config = (await _api.getConfigApi().configApp()).data!;
      final store = config.storeUrl;
      return LaunchConfig(
        minSupportedVersion: config.minSupportedVersion,
        latestVersion: config.latestVersion,
        storeUrl: store == null || store.isEmpty ? null : Uri.tryParse(store),
        maintenance: config.maintenance,
        maintenanceMessage: config.maintenanceMessage.isEmpty
            ? null
            : config.maintenanceMessage,
        termsVersion: config.termsVersion,
        policies: PolicyLinks(
          terms: Uri.parse(config.policyUrls.terms),
          privacy: Uri.parse(config.policyUrls.privacy),
          refund: Uri.parse(config.policyUrls.refund),
        ),
        otpLength: config.otp.length,
        resendAfterSeconds: config.otp.resendAfterSeconds,
        supportPhone: config.support.phone.trim().isEmpty
            ? null
            : config.support.phone.trim(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// TODO(api): used with `--dart-define=FAKE_API=true` and in tests.
class FakeConfigRepository implements ConfigRepository {
  FakeConfigRepository({LaunchConfig? config, this.failWith})
    : config = config ?? sample;

  LaunchConfig config;
  ApiError? failWith;
  int calls = 0;

  static final sample = LaunchConfig(
    maintenance: false,
    termsVersion: '2026-11-01',
    policies: PolicyLinks(
      terms: Uri.parse('https://jivo.in/terms'),
      privacy: Uri.parse('https://jivo.in/privacy'),
      refund: Uri.parse('https://jivo.in/refund'),
    ),
    minSupportedVersion: '1.0.0',
    latestVersion: '1.0.0',
    supportPhone: '+911800000000',
  );

  @override
  Future<LaunchConfig> fetch() async {
    calls++;
    final error = failWith;
    if (error != null) throw error;
    return config;
  }
}
