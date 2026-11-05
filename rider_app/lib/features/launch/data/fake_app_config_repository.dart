import 'package:jivo_api/jivo_api.dart' show AppConfig;
import 'package:jivo_core/jivo_core.dart';

import '../domain/app_config_repository.dart';

/// Which config the fake returns. Pick one in dev with
/// `--dart-define=FAKE_API=true --dart-define=FAKE_CONFIG=<name>`.
enum FakeConfigScenario {
  normal,
  softUpdate,
  forceUpdate,
  maintenance;

  static FakeConfigScenario fromEnvironment() =>
      switch (const String.fromEnvironment('FAKE_CONFIG')) {
        'soft_update' => softUpdate,
        'force_update' => forceUpdate,
        'maintenance' => maintenance,
        _ => normal,
      };
}

/// TODO(api): stands in for `GET /api/v1/config/app/` until the backend
/// implements it. Built from the schema examples (`Normal`, `Maintenance`) in
/// `backend/openapi/schema.yaml`, with the rider app's store URL and versions
/// adjusted per [scenario].
class FakeAppConfigRepository implements AppConfigRepository {
  FakeAppConfigRepository({
    this.scenario = FakeConfigScenario.normal,
    this.delay = const Duration(milliseconds: 300),
    this.failWith,
  });

  /// Can be changed between fetches (tests: maintenance ends).
  FakeConfigScenario scenario;
  final Duration delay;

  /// When set, every fetch fails with this error.
  ApiError? failWith;

  int fetchCount = 0;

  @override
  Future<AppConfig> fetch() async {
    fetchCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failWith;
    if (error != null) throw error;
    return AppConfig.fromJson(exampleJson(scenario));
  }

  /// The schema's `Normal` example, adjusted for [scenario].
  static Map<String, dynamic> exampleJson(FakeConfigScenario scenario) => {
    'min_supported_version': scenario == FakeConfigScenario.forceUpdate
        ? '9.0.0'
        : '1.0.0',
    'latest_version': switch (scenario) {
      FakeConfigScenario.softUpdate => '1.2.0',
      FakeConfigScenario.forceUpdate => '9.0.0',
      _ => '1.0.0',
    },
    'store_url': 'https://play.google.com/store/apps/details?id=in.jivo.rider',
    'maintenance': scenario == FakeConfigScenario.maintenance,
    'maintenance_message': scenario == FakeConfigScenario.maintenance
        ? 'Jivo is down for scheduled maintenance. We will be back by 6:00 AM.'
        : '',
    'support': {'phone': '+911800123456', 'email': 'support@jivo.in'},
    'policy_urls': {
      'terms': 'https://jivo.in/terms',
      'privacy': 'https://jivo.in/privacy',
      'refund': 'https://jivo.in/refund-policy',
    },
    'terms_version': '2026-11-01',
    'otp': {'length': 6, 'resend_after_seconds': 30},
    'rider_location': {
      'active_interval_seconds': 10,
      'idle_interval_seconds': 30,
      'active_sample_seconds': 5,
      'idle_sample_seconds': 30,
      'max_batch': 50,
    },
    'feature_flags': <String, bool>{},
  };
}
