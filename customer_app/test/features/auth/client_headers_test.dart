import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_config.dart';

/// DL-69: the server binds tokens to the app that asked for them, so OTP
/// verify and token refresh must also say `X-App-Name: customer`.
void main() {
  test('the test client info is the customer app', () {
    expect(testClientInfo.appName, customerAppName);
    expect(testClientInfo.headers[ClientInfo.appNameHeader], 'customer');
  });

  test('OTP verify sends X-App-Name: customer', () async {
    final http = FakeHttp((_) => (500, null));
    await expectLater(
      ApiAuthRepository(http.api()).verifyOtp(
        phone: '+919000000001',
        otp: '123456',
        termsVersion: '1',
      ),
      throwsA(isA<ApiError>()),
    );
    expect(http.requests.single.path, contains('/auth/otp/verify/'));
    expect(http.requests.single.headers[ClientInfo.appNameHeader], 'customer');
  });

  test('token refresh sends X-App-Name: customer, no Authorization', () async {
    final http = FakeHttp((_) => (200, {'access': 'a2', 'refresh': 'r2'}));
    final refresher = ApiTokenRefresher.forEnv(
      env: testEnv,
      clientInfo: testClientInfo,
      httpClientAdapter: http,
      logRequests: false,
    );
    final tokens = await refresher.refresh('r1');
    expect(tokens.access, 'a2');
    final request = http.requests.single;
    expect(request.path, contains('/auth/token/refresh/'));
    expect(request.headers[ClientInfo.appNameHeader], 'customer');
    expect(request.headers['Authorization'], isNull);
  });
}
