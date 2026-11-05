import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';

import '../../auth/presentation/rider_account_controller.dart';
import '../../launch/presentation/launch_controller.dart';
import '../../location/domain/location_service_client.dart';
import '../../location/domain/tracking_config.dart';
import '../../location/presentation/location_debug_controller.dart';
import '../../permissions/domain/permission_gate.dart';
import '../../permissions/presentation/permissions_gate_controller.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_repositories.dart';
import '../../task/presentation/task_block.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_shift_repository.dart';
import '../data/fake_shift_backend.dart';
import '../domain/shift_repository.dart';

/// The fake shift backend (`FAKE_API` builds). Overridden in tests.
final fakeShiftBackendProvider = Provider<FakeShiftBackend>(
  (ref) => FakeShiftBackend(),
);

/// `rider_shift_*` and `rider_heartbeat` (P5 slice 5.2, live), where the
/// rider work screens run (dev flavor until the whole rider API is live,
/// DL-30); the fake with `FAKE_API`.
final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) {
    return const UnavailableShiftRepository();
  }
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeShiftBackendProvider);
  }
  return ApiShiftRepository(ref.watch(jivoApiProvider));
});

/// `details.reason` values of a go-online refusal (P5 contract).
abstract final class ShiftRefusal {
  static const riderNotActive = 'RIDER_NOT_ACTIVE';
  static const documentsNotApproved = 'DOCUMENTS_NOT_APPROVED';
  static const tooFarFromStore = 'TOO_FAR_FROM_STORE';

  static String? of(ApiError? error) {
    final reason = error?.details['reason'];
    return reason is String ? reason : null;
  }
}

enum ShiftPhase { offline, goingOnline, online, goingOffline }

/// Why the last toggle did not do what the rider asked, or a notice.
enum ShiftProblem {
  /// The permissions gate does not pass (04 §2.1). [ShiftState.missingStep]
  /// says which step comes next.
  permissionsMissing,

  /// No GPS fix to send with `shift/start`.
  locationUnavailable,

  /// The server refused (guards: not ACTIVE, too far from the home store,
  /// ...). [ShiftState.error] has the server's code and message.
  server,

  /// The foreground service could not start (or stop).
  serviceFailed,

  /// Going offline is refused during a delivery task (agent rule 7).
  taskActive,

  /// The server ended the shift (no heartbeat for 10 min, 04 §2.3).
  autoOffline,

  /// Tracking stopped, but `shift/end` did not reach the server. The rider
  /// is offline on the phone; "Try again" repeats the call.
  endNotConfirmed,
}

@immutable
class ShiftState {
  const ShiftState({
    this.phase = ShiftPhase.offline,
    this.problem,
    this.error,
    this.missingStep,
    this.endPending = false,
    this.synced = true,
    this.prepaidOnly = false,
  });

  /// Before the first [ShiftController.sync]: whether the service runs is
  /// not known yet, so home shows no online control (home spec §8).
  const ShiftState.unknown() : this(synced: false);

  final ShiftPhase phase;
  final ShiftProblem? problem;
  final ApiError? error;
  final GateStep? missingStep;

  /// `shift/end` still has to reach the server.
  final bool endPending;

  final bool synced;

  /// Online with cash at the limit: prepaid offers only (`prepaid_only`).
  final bool prepaidOnly;

  bool get isOnline => phase == ShiftPhase.online;
  bool get busy =>
      phase == ShiftPhase.goingOnline || phase == ShiftPhase.goingOffline;

  ShiftState copyWith({
    ShiftPhase? phase,
    bool? endPending,
    ShiftProblem? problem,
    ApiError? error,
    GateStep? missingStep,
    bool clearProblem = false,
  }) => ShiftState(
    phase: phase ?? this.phase,
    synced: synced,
    prepaidOnly: prepaidOnly,
    endPending: endPending ?? this.endPending,
    problem: clearProblem ? null : (problem ?? this.problem),
    error: clearProblem ? null : (error ?? this.error),
    missingStep: clearProblem ? null : (missingStep ?? this.missingStep),
  );
}

final shiftControllerProvider = NotifierProvider<ShiftController, ShiftState>(
  ShiftController.new,
);

/// The online/offline toggle (04 §2.3, slice 5.2).
///
/// Going online, in order: permissions gate → one GPS fix → `shift/start`
/// (the server checks its guards) → the foreground location service with
/// the persistent "You're online" notification. If the service cannot start,
/// the shift is ended again.
///
/// Going offline: refused during a task; otherwise the service is stopped
/// **first** (no location after the rider said offline, agent rule 1), then
/// `shift/end`.
///
/// The service is the phone's source of truth for "online": on start and on
/// every return to the foreground the controller asks whether it runs. When
/// the server stops tracking (auto-offline), the service stops itself and the
/// controller shows why.
class ShiftController extends Notifier<ShiftState> {
  LocationServiceClient get _client => ref.read(locationServiceClientProvider);
  ShiftRepository get _repo => ref.read(shiftRepositoryProvider);

  /// The notification text of the running service, kept to restart it.
  OnlineNotificationText? _text;
  TrackingConfig? _config;

  @override
  ShiftState build() {
    if (!ref.watch(riderWorkActiveProvider)) return const ShiftState();
    final client = ref.watch(locationServiceClientProvider);
    final stops = client.serverStops.listen(_onServerStop);
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    ref.onDispose(() {
      stops.cancel();
      lifecycle.dispose();
    });
    Future.microtask(sync);
    return const ShiftState.unknown();
  }

  /// Reads whether the service runs (the app was reopened while online), and
  /// whether the server stopped it while the app was closed.
  Future<void> sync() async {
    if (state.busy) return;
    final bool running;
    final String? stoppedBy;
    try {
      running = await _client.isRunning();
      stoppedBy = running ? null : await _client.takeServerStop();
    } on Object catch (error) {
      debugPrint('ShiftController.sync: $error');
      return;
    }
    if (!ref.mounted || state.busy) return;
    if (!state.synced) state = state.withSynced();
    if (running) {
      state = state.copyWith(phase: ShiftPhase.online);
      _client.requestStats();
      await _reconcileWithServer();
    } else if (stoppedBy != null) {
      state = const ShiftState(problem: ShiftProblem.autoOffline);
    } else if (state.phase == ShiftPhase.online) {
      // The service died while the shift is still on (OEM battery killer,
      // force stop). Start it again rather than silently stop tracking.
      await _restartService();
    } else if (state.problem == ShiftProblem.permissionsMissing) {
      // Back from Settings: clear the guard once the gate passes.
      try {
        final gate = await ref
            .read(permissionsGateControllerProvider.notifier)
            .refresh();
        if (ref.mounted && gate.canGoOnline) dismissProblem();
      } on Object catch (error) {
        debugPrint('ShiftController.sync: gate: $error');
      }
    }
  }

  /// The service runs: ask the server whether the shift is still on
  /// (`rider_heartbeat`). If the server ended it (auto-offline, ops) while
  /// the app was away, stop tracking now and say why. A failed check
  /// changes nothing.
  Future<void> _reconcileWithServer() async {
    final ShiftStatus status;
    try {
      status = await _repo.status();
    } on Object catch (error) {
      debugPrint('ShiftController: status check failed: $error');
      return;
    }
    if (!ref.mounted || status.isOnline || state.busy) return;
    try {
      await _client.stop();
    } on Object catch (error) {
      debugPrint('ShiftController: stop after server offline: $error');
    }
    if (ref.mounted) {
      state = ShiftState(
        problem: status.endedBy == ShiftEndedBy.rider
            ? null
            : ShiftProblem.autoOffline,
      );
    }
  }

  Future<void> _restartService() async {
    final text =
        _text ?? _defaultText(lookupAppLocalizations(const Locale('en')));
    final config = _config ?? _baseConfig();
    try {
      await _client.start(
        config: config,
        mode: _mode(),
        simulateOffline: false,
        text: text,
      );
    } on Object catch (error) {
      debugPrint('ShiftController: restart failed: $error');
      if (ref.mounted) {
        state = const ShiftState(problem: ShiftProblem.serviceFailed);
      }
    }
  }

  void _onServerStop(String code) {
    if (!ref.mounted) return;
    unawaited(_client.takeServerStop());
    state = const ShiftState(problem: ShiftProblem.autoOffline);
  }

  TrackingMode _mode() => ref.read(taskBlocksGoingOfflineProvider)
      ? TrackingMode.onTask
      : TrackingMode.idle;

  /// The `config/app` `rider_location` periods, or the 04 §3 defaults.
  TrackingConfig _baseConfig() {
    final location = ref.read(launchControllerProvider).config?.riderLocation;
    return location == null
        ? const TrackingConfig()
        : applyRiderLocation(const TrackingConfig(), location);
  }

  static OnlineNotificationText _defaultText(AppLocalizations l10n) =>
      OnlineNotificationText(
        title: l10n.onlineNotificationTitle,
        body: l10n.onlineNotificationText,
        channelName: l10n.onlineChannelName,
        channelDescription: l10n.onlineChannelDescription,
      );

  /// Returns true once the rider is online. [text] is the localised
  /// persistent notification.
  Future<bool> goOnline(OnlineNotificationText text) async {
    if (state.phase != ShiftPhase.offline) return false;
    state = state.copyWith(phase: ShiftPhase.goingOnline, clearProblem: true);

    // 1. Permissions (and the prominent disclosure) before anything else.
    final GateEvaluation gate;
    try {
      gate = await ref
          .read(permissionsGateControllerProvider.notifier)
          .refresh();
    } on Object catch (error) {
      debugPrint('ShiftController: permission check failed: $error');
      return _offlineWith(ShiftProblem.permissionsMissing);
    }
    if (!ref.mounted) return false;
    if (!gate.canGoOnline) {
      return _offlineWith(
        ShiftProblem.permissionsMissing,
        missingStep: gate.next?.step,
      );
    }

    // 2. Where the rider is: the server checks the home-store radius.
    final GeoPoint at;
    try {
      at = await ref.read(currentLocationReaderProvider).current();
    } on LocationUnavailable {
      return _offlineWith(ShiftProblem.locationUnavailable);
    } on Object catch (error) {
      debugPrint('ShiftController: location failed: $error');
      return _offlineWith(ShiftProblem.locationUnavailable);
    }
    if (!ref.mounted) return false;

    // 3. The server decides.
    final ShiftStart started;
    try {
      started = await _repo.start(at);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return false;
      if (reportAppControlError(ref, error)) {
        return _offlineWith(null);
      }
      return _offlineWith(ShiftProblem.server, error: error);
    }
    if (!ref.mounted) return false;

    // 4. The foreground service with the "You're online" notification.
    final config = started.applyTo(_baseConfig());
    try {
      await _client.takeServerStop(); // A stale marker from an old shift.
      await _client.start(
        config: config,
        mode: _mode(),
        simulateOffline: false,
        text: text,
      );
    } on Object catch (error) {
      debugPrint('ShiftController: service start failed: $error');
      // Online on the server but not tracked: end the shift again.
      try {
        await _repo.end();
      } on Object catch (endError) {
        debugPrint('ShiftController: rollback shift/end failed: $endError');
      }
      return _offlineWith(ShiftProblem.serviceFailed);
    }
    if (!ref.mounted) return true;
    _text = text;
    _config = config;
    state = ShiftState(
      phase: ShiftPhase.online,
      prepaidOnly: started.prepaidOnly,
    );
    return true;
  }

  bool _offlineWith(
    ShiftProblem? problem, {
    ApiError? error,
    GateStep? missingStep,
  }) {
    if (ref.mounted) {
      state = ShiftState(
        problem: problem,
        error: error,
        missingStep: missingStep,
        endPending: state.endPending,
      );
    }
    return false;
  }

  /// Returns true once tracking has stopped (even if `shift/end` still has
  /// to reach the server, see [ShiftProblem.endNotConfirmed]).
  Future<bool> goOffline() async {
    if (state.busy) return false;
    if (state.phase != ShiftPhase.online) {
      // Not synced yet (the app just started): the service decides.
      try {
        if (!await _client.isRunning()) return false;
      } on Object {
        return false;
      }
      if (!ref.mounted) return false;
    }
    if (ref.read(taskBlocksGoingOfflineProvider)) {
      state = state.copyWith(
        phase: ShiftPhase.online,
        problem: ShiftProblem.taskActive,
      );
      return false;
    }
    state = state.copyWith(phase: ShiftPhase.goingOffline, clearProblem: true);
    try {
      await _client.stop();
    } on Object catch (error) {
      debugPrint('ShiftController: service stop failed: $error');
      if (ref.mounted) {
        state = const ShiftState(
          phase: ShiftPhase.online,
          problem: ShiftProblem.serviceFailed,
        );
      }
      return false;
    }
    _text = null;
    _config = null;
    if (!ref.mounted) return true;
    state = const ShiftState(endPending: true);
    await retryEnd();
    return true;
  }

  /// Sends `shift/end` again after [ShiftProblem.endNotConfirmed].
  Future<void> retryEnd() async {
    if (!state.endPending || state.phase != ShiftPhase.offline) return;
    try {
      await _repo.end();
      if (ref.mounted) state = const ShiftState();
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      reportAppControlError(ref, error);
      state = ShiftState(
        endPending: true,
        problem: ShiftProblem.endNotConfirmed,
        error: error,
      );
    }
  }

  /// Hides the current notice.
  void dismissProblem() {
    if (state.problem != null) state = state.copyWith(clearProblem: true);
  }
}

extension on ShiftState {
  ShiftState withSynced() => ShiftState(
    phase: phase,
    problem: problem,
    error: error,
    missingStep: missingStep,
    endPending: endPending,
    prepaidOnly: prepaidOnly,
  );
}
