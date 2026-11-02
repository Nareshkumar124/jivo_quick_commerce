import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show AppConfig;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../data/api_app_config_repository.dart';
import '../data/fake_app_config_repository.dart';
import '../domain/app_config_repository.dart';
import '../domain/launch_gate.dart';

/// The real repository, or the fake one when `FAKE_API` is on.
final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return FakeAppConfigRepository(
      scenario: FakeConfigScenario.fromEnvironment(),
    );
  }
  return ApiAppConfigRepository(ref.watch(jivoApiProvider));
});

@immutable
class LaunchState {
  const LaunchState({
    this.config,
    this.loading = false,
    this.error,
    this.softUpdatePending = false,
    this.softUpdateDismissed = false,
  });

  /// The last config loaded. Login needs `terms_version` and `policy_urls`.
  /// Null until the first successful load: the app stays on the splash.
  final AppConfig? config;
  final bool loading;

  /// Why the last load failed (splash shows it with a Retry button).
  final ApiError? error;

  /// The installed version is below `latest_version`: show the dismissible
  /// update prompt.
  final bool softUpdatePending;

  /// The rider chose "Later" this session.
  final bool softUpdateDismissed;

  Uri get storeUrl => storeUriOf(config?.storeUrl);

  LaunchState copyWith({
    AppConfig? config,
    bool? loading,
    ApiError? error,
    bool clearError = false,
    bool? softUpdatePending,
    bool? softUpdateDismissed,
  }) => LaunchState(
    config: config ?? this.config,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    softUpdatePending: softUpdatePending ?? this.softUpdatePending,
    softUpdateDismissed: softUpdateDismissed ?? this.softUpdateDismissed,
  );
}

/// App control on start (04 §2.1): loads `config/app` and turns it into
/// jivo_core [AppControlSignals] (maintenance, force update) plus the
/// rider-local optional update prompt. Not auto-disposed: the config is
/// needed for the whole session.
final launchControllerProvider =
    NotifierProvider<LaunchController, LaunchState>(LaunchController.new);

class LaunchController extends Notifier<LaunchState> {
  @override
  LaunchState build() => const LaunchState();

  /// Fetches the config. Errors go to [LaunchState.error]; nothing is
  /// retried automatically.
  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final AppConfig config;
    try {
      config = await ref.read(appConfigRepositoryProvider).fetch();
    } on Object catch (error) {
      state = state.copyWith(loading: false, error: ApiError.from(error));
      return;
    }

    final gate = launchGateFor(
      config,
      appVersion: ref.read(clientInfoProvider).appVersion,
      softUpdateDismissed: state.softUpdateDismissed,
    );
    final signals = ref.read(appControlSignalsProvider);
    switch (gate) {
      case LaunchMaintenance(:final message):
        signals.reportMaintenance(
          MaintenanceMode(message: message.trim().isEmpty ? null : message),
        );
      case LaunchUpdate(forced: true, :final storeUrl):
        signals.reportUpdateRequired(
          AppUpdateRequired(
            minSupportedVersion: config.minSupportedVersion,
            latestVersion: config.latestVersion,
            storeUrl: storeUrl,
          ),
        );
      case LaunchUpdate() || LaunchProceed():
        signals.clearMaintenance();
    }
    state = state.copyWith(
      config: config,
      loading: false,
      softUpdatePending: gate is LaunchUpdate && !gate.forced,
    );
  }

  /// "Later" on the optional update prompt. Remembered for this session.
  void dismissSoftUpdate() {
    state = state.copyWith(softUpdatePending: false, softUpdateDismissed: true);
  }
}
