import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show Me, RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/data/fake_auth_backend.dart';
import 'package:rider_app/features/auth/domain/account_repository.dart';
import 'package:rider_app/features/auth/domain/rider_account.dart';
import 'package:rider_app/features/auth/presentation/auth_providers.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';

import '../../../helpers/rider_app_harness.dart';

class FailingAccounts implements AccountRepository {
  FailingAccounts(this.error);

  final ApiError error;

  @override
  Future<Me> fetchMe() async => throw error;
}

class FailingLogout extends FakeAuthBackend {
  FailingLogout() : super(delay: Duration.zero);

  @override
  Future<void> logout({required String refreshToken}) async =>
      throw const ApiError(code: ApiErrorCode.network);
}

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  test('restores rider_status from GET /me/ on app start', () async {
    await h.signedInBefore('+919811122232'); // ends in 2: PENDING_KYC
    final c = await h.container();

    await c.read(riderAccountControllerProvider.notifier).load();

    expect(
      c.read(riderAccountControllerProvider),
      isA<AccountLoaded>().having(
        (s) => s.riderStatus,
        'riderStatus',
        RiderStatusEnum.PENDING_KYC,
      ),
    );
  });

  test('a network failure keeps the session (no random logouts)', () async {
    await h.signedInBefore('+919811122231');
    final c = await h.container(
      extra: [
        accountRepositoryProvider.overrideWithValue(
          FailingAccounts(const ApiError(code: ApiErrorCode.network)),
        ),
      ],
    );

    await c.read(riderAccountControllerProvider.notifier).load();

    expect(c.read(riderAccountControllerProvider), isA<AccountLoadFailed>());
    expect(h.session.isSignedIn, isTrue);
    expect(await h.tokenStore.read(), isNotNull);
    expect(h.cleaner.clears, 0);
  });

  test('a 401 that survived the refresh ends the session as expired', () async {
    await h.signedInBefore('+919811122231');
    final c = await h.container(
      extra: [
        accountRepositoryProvider.overrideWithValue(
          FailingAccounts(
            const ApiError(code: ApiErrorCode.authRequired, statusCode: 401),
          ),
        ),
      ],
    );

    await c.read(riderAccountControllerProvider.notifier).load();

    expect(h.session.status, SessionStatus.signedOut);
    expect(h.session.lastSignOutReason, SignOutReason.sessionExpired);
    expect(await h.tokenStore.read(), isNull);
    expect(h.cleaner.clears, 1, reason: 'rider data deleted by the hook');
  });

  test('a session expired by jivo_core (refresh rejected) also deletes rider '
      'data', () async {
    await h.signedInBefore('+919811122231');
    final c = await h.container();
    await c.read(riderAccountControllerProvider.notifier).load();

    await h.session.signOut(reason: SignOutReason.sessionExpired);

    expect(h.cleaner.clears, 1);
    expect(c.read(riderAccountControllerProvider), isA<AccountUnknown>());
  });

  test('logout is refused while online', () async {
    await h.signedInBefore('+919811122231');
    final c = await h.container();
    h.location.running = true;

    final result = await c
        .read(riderAccountControllerProvider.notifier)
        .logout();

    expect(result, LogoutResult.blockedWhileOnline);
    expect(h.session.isSignedIn, isTrue);
    expect(h.backend.calls, isNot(contains('logout')));
  });

  test('logout revokes the refresh token, ends the session and deletes the '
      'location buffer', () async {
    await h.signedInBefore('+919811122231');
    final c = await h.container();
    await c.read(riderAccountControllerProvider.notifier).load();

    final result = await c
        .read(riderAccountControllerProvider.notifier)
        .logout();

    expect(result, LogoutResult.done);
    expect(h.backend.calls, contains('logout'));
    expect(h.session.status, SessionStatus.signedOut);
    expect(h.session.lastSignOutReason, SignOutReason.userRequested);
    expect(await h.tokenStore.read(), isNull);
    expect(h.cleaner.clears, 1);
    expect(h.offerAlerts.dismissed, 1);
    expect(c.read(riderAccountControllerProvider), isA<AccountUnknown>());
  });

  test(
    'logout still ends the local session when the server call fails',
    () async {
      await h.signedInBefore('+919811122231');
      final c = await h.container(
        extra: [authRepositoryProvider.overrideWithValue(FailingLogout())],
      );

      final result = await c
          .read(riderAccountControllerProvider.notifier)
          .logout();

      expect(result, LogoutResult.done);
      expect(h.session.status, SessionStatus.signedOut);
      expect(h.cleaner.clears, 1);
    },
  );
}
