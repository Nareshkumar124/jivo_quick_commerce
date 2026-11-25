import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

/// `GET /config/app/` → `LaunchConfig`: the support contacts.
void main() {
  Map<String, Object?> configJson({
    required String phone,
    required String email,
  }) => {
    'min_supported_version': '1.0.0',
    'latest_version': '1.0.0',
    'store_url': null,
    'maintenance': false,
    'maintenance_message': '',
    'support': {'phone': phone, 'email': email},
    'policy_urls': {
      'terms': 'https://jivo.in/terms',
      'privacy': 'https://jivo.in/privacy',
      'refund': 'https://jivo.in/refund',
    },
    'terms_version': '2026-11-01',
    'otp': {'length': 6, 'resend_after_seconds': 30},
    'rider_location': {
      'active_interval_seconds': 10,
      'idle_interval_seconds': 60,
      'active_sample_seconds': 5,
      'idle_sample_seconds': 30,
      'max_batch': 20,
    },
    'feature_flags': <String, bool>{},
  };

  test('maps support phone and email (trimmed)', () async {
    final http = FakeHttp(
      (_) =>
          (200, configJson(phone: ' +919910557187 ', email: ' info@jivo.in ')),
    );
    final config = await ApiConfigRepository(http.api()).fetch();
    expect(http.requests.single.uri.path, '/api/v1/config/app/');
    expect(config.supportPhone, '+919910557187');
    expect(config.supportEmail, 'info@jivo.in');
  });

  test('an empty support email or phone is null', () async {
    final http = FakeHttp((_) => (200, configJson(phone: '', email: '  ')));
    final config = await ApiConfigRepository(http.api()).fetch();
    expect(config.supportPhone, isNull);
    expect(config.supportEmail, isNull);
  });
}
