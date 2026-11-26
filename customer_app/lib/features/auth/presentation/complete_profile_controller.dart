import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_controllers.dart';

/// Which complete-profile button is waiting for the server.
enum CompleteProfileAction { submit, skip }

@immutable
class CompleteProfileState {
  const CompleteProfileState({this.busy, this.error});

  /// The action in flight, or null. Both buttons are disabled meanwhile.
  final CompleteProfileAction? busy;
  final Object? error;

  bool get isBusy => busy != null;

  /// The server rejected the business category (shown under the dropdown).
  bool get categoryRejected => businessCategoryRejected(error);
}

/// The complete-profile screen (`03 §2.2`): Submit sends the name and the
/// optional business fields, Skip tells the server not to ask again. Either
/// way the server returns the user with `is_profile_complete: true`; the
/// cached user is replaced and the router moves on to home.
class CompleteProfileController extends Notifier<CompleteProfileState> {
  @override
  CompleteProfileState build() => const CompleteProfileState();

  /// `PATCH /me/`. Returns true on success. Ignored while busy.
  Future<bool> submit({
    required String name,
    int? businessCategoryId,
    String businessName = '',
  }) => _run(
    CompleteProfileAction.submit,
    () => ref
        .read(profileRepositoryProvider)
        .submitBusinessProfile(
          name: name,
          businessCategoryId: businessCategoryId,
          businessName: businessName,
        ),
  );

  /// `POST /me/profile-prompt/skip/`. Returns true on success.
  Future<bool> skip() => _run(
    CompleteProfileAction.skip,
    () => ref.read(profileRepositoryProvider).skipProfilePrompt(),
  );

  Future<bool> _run(
    CompleteProfileAction action,
    Future<UserProfile> Function() call,
  ) async {
    if (state.isBusy) return false;
    state = CompleteProfileState(busy: action);
    try {
      final user = await call();
      if (!ref.mounted) return false;
      state = const CompleteProfileState();
      // Updates the launch state: the router leaves complete-profile.
      ref.read(currentUserProvider.notifier).replace(user);
      return true;
    } catch (error) {
      if (ref.mounted) state = CompleteProfileState(error: error);
      return false;
    }
  }
}

final completeProfileProvider =
    NotifierProvider.autoDispose<
      CompleteProfileController,
      CompleteProfileState
    >(CompleteProfileController.new);
