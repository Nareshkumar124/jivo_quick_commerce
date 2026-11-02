import 'package:jivo_core/jivo_core.dart';

/// TODO(api): issues new fake tokens; used with `FAKE_API` and in tests.
class FakeTokenRefresher implements TokenRefresher {
  int calls = 0;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    calls++;
    return AuthTokens(
      access: 'fake-access-r$calls',
      refresh: 'fake-refresh-r$calls',
    );
  }
}
