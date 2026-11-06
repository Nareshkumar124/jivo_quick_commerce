import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../shift/presentation/shift_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/service_isolate_api.dart';
import '../data/foreground_location_service.dart';
import '../domain/location_service_client.dart';
import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';

/// The foreground location service. It uploads to the real API where the
/// shift API is bound (dev without `FAKE_API`), else to the fake.
final locationServiceClientProvider = Provider<LocationServiceClient>(
  (ref) => ForegroundLocationService(
    api: ServiceApiSettings.fromEnv(
      ref.watch(appEnvProvider),
      live: ref.watch(riderWorkEnabledProvider),
    ),
  ),
);

enum LocationDebugError {
  permissionsMissing,
  startFailed,

  /// Going offline is blocked while a delivery task is active (rule 7).
  taskActive,
}

@immutable
class LocationDebugState {
  const LocationDebugState({
    this.online = false,
    this.busy = false,
    this.mode = TrackingMode.idle,
    this.simulateOffline = false,
    this.simulateServerOffline = false,
    this.stats,
    this.error,
    this.errorDetail,
  });

  final bool online;
  final bool busy;
  final TrackingMode mode;
  final bool simulateOffline;
  final bool simulateServerOffline;
  final TrackerStats? stats;
  final LocationDebugError? error;
  final String? errorDetail;

  LocationDebugState copyWith({
    bool? online,
    bool? busy,
    TrackingMode? mode,
    bool? simulateOffline,
    bool? simulateServerOffline,
    TrackerStats? stats,
    LocationDebugError? error,
    String? errorDetail,
    bool clearError = false,
  }) => LocationDebugState(
    online: online ?? this.online,
    busy: busy ?? this.busy,
    mode: mode ?? this.mode,
    simulateOffline: simulateOffline ?? this.simulateOffline,
    simulateServerOffline: simulateServerOffline ?? this.simulateServerOffline,
    stats: stats ?? this.stats,
    error: clearError ? null : (error ?? this.error),
    errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
  );
}

final locationDebugControllerProvider =
    NotifierProvider<LocationDebugController, LocationDebugState>(
      LocationDebugController.new,
    );

/// Dev diagnostics for the location service (Phase 0 spike screen). Going
/// online and offline goes through the real [ShiftController], so this
/// screen and home always agree.
class LocationDebugController extends Notifier<LocationDebugState> {
  LocationServiceClient get _client => ref.read(locationServiceClientProvider);

  @override
  LocationDebugState build() {
    final client = ref.watch(locationServiceClientProvider);
    final subscription = client.stats.listen(_onStats);
    ref.onDispose(subscription.cancel);
    Future.microtask(syncWithService);
    return const LocationDebugState();
  }

  void _onStats(TrackerStats stats) {
    state = state.copyWith(
      stats: stats,
      mode: stats.mode,
      online: stats.running,
    );
  }

  /// The service may already be running (app reopened while online).
  Future<void> syncWithService() async {
    final running = await _client.isRunning();
    if (!ref.mounted) return;
    state = state.copyWith(online: running);
    if (running) _client.requestStats();
  }

  /// Returns false if the permissions gate does not pass or the service
  /// fails to start; [LocationDebugState.error] says why.
  Future<bool> goOnline(OnlineNotificationText text) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    final shift = ref.read(shiftControllerProvider.notifier);
    final ok = await shift.goOnline(text);
    if (!ref.mounted) return ok;
    final after = ref.read(shiftControllerProvider);
    state = state.copyWith(
      busy: false,
      online: ok,
      error: ok ? null : _errorOf(after.problem),
      errorDetail: after.error?.rawCode ?? after.error?.code.name,
    );
    if (ok) {
      if (state.simulateOffline) _client.setSimulateOffline(true);
      if (state.mode != TrackingMode.idle) _client.setMode(state.mode);
    }
    return ok;
  }

  static LocationDebugError _errorOf(ShiftProblem? problem) =>
      switch (problem) {
        ShiftProblem.permissionsMissing =>
          LocationDebugError.permissionsMissing,
        ShiftProblem.taskActive => LocationDebugError.taskActive,
        _ => LocationDebugError.startFailed,
      };

  Future<void> goOffline() async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    await ref.read(shiftControllerProvider.notifier).goOffline();
    if (!ref.mounted) return;
    final after = ref.read(shiftControllerProvider);
    state = state.copyWith(
      busy: false,
      online: after.isOnline,
      error:
          after.problem == ShiftProblem.taskActive ||
              after.problem == ShiftProblem.serviceFailed
          ? _errorOf(after.problem)
          : null,
    );
  }

  void setMode(TrackingMode mode) {
    state = state.copyWith(mode: mode);
    if (state.online) _client.setMode(mode);
  }

  void setSimulateOffline(bool value) {
    state = state.copyWith(simulateOffline: value);
    if (state.online) _client.setSimulateOffline(value);
  }

  void setSimulateServerOffline(bool value) {
    state = state.copyWith(simulateServerOffline: value);
    if (state.online) _client.setSimulateServerOffline(value);
  }

  void flush() {
    if (state.online) _client.flush();
  }
}
