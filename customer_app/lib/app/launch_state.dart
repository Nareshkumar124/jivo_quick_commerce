import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/launch/domain/launch_config.dart';
import '../features/profile/domain/user_profile.dart';
import 'providers.dart';

/// Start-up and routing state besides the session and app control: whether
/// the config has loaded, onboarding was seen, and the signed-in user's
/// profile state. A [ChangeNotifier] for go_router's `refreshListenable`.
class LaunchState extends ChangeNotifier {
  LaunchState({required this._onboardingSeen});

  LaunchConfig? _config;
  bool _ready = false;
  bool _onboardingSeen;
  UserProfile? _user;
  bool? _profileComplete;
  bool _updateAvailable = false;
  bool _updatePromptDismissed = false;

  /// The last loaded `config/app`.
  LaunchConfig? get config => _config;

  /// True once the splash finished (config loaded, user loaded if signed in).
  bool get ready => _ready;

  bool get onboardingSeen => _onboardingSeen;

  /// The signed-in user, when known.
  UserProfile? get user => _user;

  /// False sends a signed-in user to complete-profile; null means unknown.
  bool? get profileComplete => _profileComplete;

  /// Show the dismissible "newer version" prompt (once per app start).
  bool get showUpdatePrompt => _updateAvailable && !_updatePromptDismissed;

  void configLoaded(LaunchConfig config, {required bool updateAvailable}) {
    _config = config;
    _updateAvailable = updateAvailable;
    notifyListeners();
  }

  void markReady() {
    if (_ready) return;
    _ready = true;
    notifyListeners();
  }

  void markOnboardingSeen() {
    _onboardingSeen = true;
    notifyListeners();
  }

  /// Sets the user; [profileComplete] defaults to the user's own flag.
  void setUser(UserProfile user, {bool? profileComplete}) {
    _user = user;
    _profileComplete = profileComplete ?? user.isProfileComplete;
    notifyListeners();
  }

  /// Forgets the user (sign-out).
  void clearUser() {
    _user = null;
    _profileComplete = null;
    notifyListeners();
  }

  void dismissUpdatePrompt() {
    _updatePromptDismissed = true;
    notifyListeners();
  }
}

/// The signed-in user's id, or null when signed out or not loaded yet.
/// Unlike reading [LaunchState.user], watching this rebuilds when another
/// user signs in or the user signs out (by any path: logout, deletion,
/// expired session), so per-user data kept for the session can key on it.
class SignedInUserId extends Notifier<int?> {
  @override
  int? build() {
    final launch = ref.watch(launchStateProvider);
    void sync() {
      final id = launch.user?.id;
      if (id != state) state = id;
    }

    launch.addListener(sync);
    ref.onDispose(() => launch.removeListener(sync));
    return launch.user?.id;
  }
}

final signedInUserIdProvider = NotifierProvider<SignedInUserId, int?>(
  SignedInUserId.new,
);

/// Whether the signed-in user has a phone; null when signed out or not
/// loaded. False for an email sign-up that has not added one: checkout then
/// needs a contact number on the address. Rebuilds on any user change.
class SignedInUserHasPhone extends Notifier<bool?> {
  @override
  bool? build() {
    final launch = ref.watch(launchStateProvider);
    void sync() {
      final value = launch.user?.hasPhone;
      if (value != state) state = value;
    }

    launch.addListener(sync);
    ref.onDispose(() => launch.removeListener(sync));
    return launch.user?.hasPhone;
  }
}

final signedInUserHasPhoneProvider =
    NotifierProvider<SignedInUserHasPhone, bool?>(SignedInUserHasPhone.new);

final launchStateProvider = Provider<LaunchState>((ref) {
  final state = LaunchState(
    onboardingSeen: ref.watch(appFlagsProvider).onboardingSeen,
  );
  ref.onDispose(state.dispose);
  return state;
});
