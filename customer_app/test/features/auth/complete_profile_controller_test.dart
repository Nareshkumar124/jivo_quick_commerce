import 'dart:async';

import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/auth/domain/auth_models.dart';
import 'package:customer_app/features/auth/presentation/complete_profile_controller.dart';
import 'package:customer_app/features/profile/data/profile_repository.dart';
import 'package:customer_app/features/profile/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

const _newUser = UserProfile(
  id: 2,
  phone: '+919876543210',
  name: '',
  isProfileComplete: false,
);

/// Holds the skip call open until [release] completes.
class _SlowProfileRepository extends FakeProfileRepository {
  _SlowProfileRepository() : super(_newUser);

  final release = Completer<void>();

  @override
  Future<UserProfile> skipProfilePrompt() async {
    await release.future;
    return super.skipProfilePrompt();
  }
}

void main() {
  late LaunchState launch;

  ProviderContainer containerWith(FakeProfileRepository repo) {
    launch = LaunchState(onboardingSeen: true)..setUser(_newUser);
    final container = ProviderContainer(
      overrides: [
        launchStateProvider.overrideWithValue(launch),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose controller alive for the whole test.
    container.listen(completeProfileProvider, (_, _) {});
    return container;
  }

  test('submit sends the fields and completes the cached user', () async {
    final repo = FakeProfileRepository(_newUser);
    final container = containerWith(repo);
    expect(launch.profileComplete, isFalse);

    final ok = await container
        .read(completeProfileProvider.notifier)
        .submit(name: ' Asha ', businessCategoryId: 2, businessName: 'Shop');

    expect(ok, isTrue);
    expect(repo.businessSubmits.single, ('Asha', 2, 'Shop'));
    expect(launch.profileComplete, isTrue);
    expect(launch.user?.businessCategoryName, 'Restaurant / Café');
    expect(container.read(completeProfileProvider).isBusy, isFalse);
  });

  test('skip calls the skip endpoint and keeps the name empty', () async {
    final repo = FakeProfileRepository(_newUser);
    final container = containerWith(repo);

    final ok = await container.read(completeProfileProvider.notifier).skip();

    expect(ok, isTrue);
    expect(repo.skips, 1);
    expect(repo.businessSubmits, isEmpty);
    expect(launch.profileComplete, isTrue);
    expect(launch.user?.name, isEmpty);
    expect(launch.user?.hasName, isFalse);
  });

  test('no double submit: a second tap while busy is ignored', () async {
    final repo = _SlowProfileRepository();
    final container = containerWith(repo);
    final notifier = container.read(completeProfileProvider.notifier);

    final first = notifier.skip();
    expect(
      container.read(completeProfileProvider).busy,
      CompleteProfileAction.skip,
    );
    expect(await notifier.submit(name: 'Asha'), isFalse);
    expect(await notifier.skip(), isFalse);

    repo.release.complete();
    expect(await first, isTrue);
    expect(repo.skips, 1);
    expect(repo.businessSubmits, isEmpty);
  });

  test('a rejected category is kept as a field error', () async {
    final repo = FakeProfileRepository(_newUser)
      ..updateError = const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 400,
        details: {
          'business_category': ['Choose a business category from the list.'],
        },
      );
    final container = containerWith(repo);

    final ok = await container
        .read(completeProfileProvider.notifier)
        .submit(name: 'Asha', businessCategoryId: 99);

    expect(ok, isFalse);
    final state = container.read(completeProfileProvider);
    expect(state.categoryRejected, isTrue);
    expect(state.isBusy, isFalse);
    expect(launch.profileComplete, isFalse);
  });

  group('needsProfile follows only is_profile_complete (03 §2.2)', () {
    SignInResult result({required bool isNew, required bool complete}) =>
        SignInResult(
          tokens: const AuthTokens(access: 'a', refresh: 'r'),
          user: UserProfile(
            id: 1,
            phone: '+919000000001',
            name: '',
            isProfileComplete: complete,
          ),
          isNewUser: isNew,
          deletionCancelled: false,
        );

    test('incomplete profile needs the screen', () {
      expect(result(isNew: true, complete: false).needsProfile, isTrue);
      expect(result(isNew: false, complete: false).needsProfile, isTrue);
    });

    test('a new user whose profile is complete does not', () {
      expect(result(isNew: true, complete: true).needsProfile, isFalse);
    });
  });
}
