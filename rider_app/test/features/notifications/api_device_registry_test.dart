import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/notifications/data/api_device_registry.dart';

import '../../helpers/canned_http.dart';

void main() {
  const clientInfo = ClientInfo(
    appName: 'rider',
    appVersion: '1.0.0',
    buildNumber: '7',
    platform: 'android',
  );

  test('register: POST /me/devices/ as the rider app on Android', () async {
    final http = CannedAdapter();
    http.answers['/api/v1/me/devices/'] = const Canned(200, {
      'id': 7,
      'fcm_token': 'tok',
      'app': 'rider',
      'platform': 'android',
      'app_version': '1.0.0+7',
      'is_active': true,
      'last_seen_at': '2026-11-05T10:00:00Z',
    });
    await ApiDeviceRegistry(cannedApi(http), clientInfo).register('tok');
    final body = http.jsonBody('/api/v1/me/devices/');
    expect(body, {
      'fcm_token': 'tok',
      'app': 'rider',
      'platform': 'android',
      'app_version': '1.0.0+7',
    });
  });

  test('unregister: DELETE /me/devices/ with the fcm_token body', () async {
    final http = CannedAdapter();
    http.answers['/api/v1/me/devices/'] = const Canned(204);
    await ApiDeviceRegistry(cannedApi(http), clientInfo).unregister('tok');
    expect(http.requests.single.method, 'DELETE');
    expect(http.jsonBody('/api/v1/me/devices/'), {'fcm_token': 'tok'});
  });
}
