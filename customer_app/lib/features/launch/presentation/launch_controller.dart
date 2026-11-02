import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../domain/launch_config.dart';

/// Applies `config/app`: force update, maintenance and the optional-update
/// prompt (`03 §2.1`). `config/app` never answers 426/503, so the version
/// checks happen here.
void applyConfig(Ref ref, LaunchConfig config) {
  final signals = ref.read(appControlProvider);
  final version = ref.read(clientInfoProvider).appVersion;
  if (isVersionBelow(version, config.minSupportedVersion)) {
    signals.reportUpdateRequired(
      AppUpdateRequired(
        minSupportedVersion: config.minSupportedVersion,
        latestVersion: config.latestVersion,
        storeUrl: config.storeUrl,
      ),
    );
  }
  if (config.maintenance) {
    signals.reportMaintenance(
      MaintenanceMode(message: config.maintenanceMessage),
    );
  } else {
    signals.clearMaintenance();
  }
  ref
      .read(launchStateProvider)
      .configLoaded(
        config,
        updateAvailable: isVersionBelow(version, config.latestVersion),
      );
}

/// The splash's start-up sequence: load the config, then the signed-in
/// user's profile (it decides whether complete-profile is needed). Errors
/// show on the splash with Retry.
class SplashController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final launch = ref.read(launchStateProvider);
    final config = await ref.read(configRepositoryProvider).fetch();
    if (!ref.mounted) return;
    applyConfig(ref, config);

    final session = ref.read(sessionProvider);
    if (session.isSignedIn && launch.user == null) {
      try {
        final user = await ref.read(profileRepositoryProvider).fetchMe();
        if (!ref.mounted) return;
        launch.setUser(user);
      } catch (_) {
        // The refresh token was rejected meanwhile: the session ended and the
        // router goes to login. Anything else (offline) shows Retry.
        if (session.isSignedIn) rethrow;
      }
    }
    launch.markReady();
  }
}

final splashControllerProvider =
    AsyncNotifierProvider.autoDispose<SplashController, void>(
      SplashController.new,
      retry: noAutomaticRetry,
    );

/// Re-reads `config/app`, e.g. from the maintenance screen.
final refreshConfigProvider = Provider<Future<void> Function()>(
  (ref) =>
      () async =>
          applyConfig(ref, await ref.read(configRepositoryProvider).fetch()),
);
