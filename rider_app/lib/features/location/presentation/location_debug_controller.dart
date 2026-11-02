import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../permissions/presentation/permissions_gate_controller.dart';
import '../../task/presentation/task_block.dart';
import '../data/foreground_location_service.dart';
import '../domain/location_service_client.dart';
import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';

final locationServiceClientProvider = Provider<LocationServiceClient>(
  (ref) => ForegroundLocationService(),
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
    this.stats,
    this.error,
    this.errorDetail,
  });

  final bool online;
  final bool busy;
  final TrackingMode mode;
  final bool simulateOffline;
  final TrackerStats? stats;
  final LocationDebugError? error;
  final String? errorDetail;

  LocationDebugState copyWith({
    bool? online,
    bool? busy,
    TrackingMode? mode,
    bool? simulateOffline,
    TrackerStats? stats,
    LocationDebugError? error,
    String? errorDetail,
    bool clearError = false,
  }) => LocationDebugState(
    online: online ?? this.online,
    busy: busy ?? this.busy,
    mode: mode ?? this.mode,
    simulateOffline: simulateOffline ?? this.simulateOffline,
    stats: stats ?? this.stats,
    error: clearError ? null : (error ?? this.error),
    errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
  );
}

final locationDebugControllerProvider =
    NotifierProvider<LocationDebugController, LocationDebugState>(
      LocationDebugController.new,
    );

/// Stand-in for the P5 online/offline toggle: starts and stops the location
/// service, behind the permissions gate.
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
    try {
      final gate = await ref
          .read(permissionsGateControllerProvider.notifier)
          .refresh();
      if (!gate.canGoOnline) {
        state = state.copyWith(
          busy: false,
          error: LocationDebugError.permissionsMissing,
        );
        return false;
      }
      await _client.start(
        config: const TrackingConfig(),
        mode: state.mode,
        simulateOffline: state.simulateOffline,
        text: text,
      );
      state = state.copyWith(online: true, busy: false);
      return true;
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        error: LocationDebugError.startFailed,
        errorDetail: '$error',
      );
      return false;
    }
  }

  Future<void> goOffline() async {
    if (state.busy) return;
    if (ref.read(taskBlocksGoingOfflineProvider)) {
      state = state.copyWith(error: LocationDebugError.taskActive);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _client.stop();
      state = state.copyWith(online: false, busy: false);
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        error: LocationDebugError.startFailed,
        errorDetail: '$error',
      );
    }
  }

  void setMode(TrackingMode mode) {
    state = state.copyWith(mode: mode);
    if (state.online) _client.setMode(mode);
  }

  void setSimulateOffline(bool value) {
    state = state.copyWith(simulateOffline: value);
    if (state.online) _client.setSimulateOffline(value);
  }

  void flush() {
    if (state.online) _client.flush();
  }
}
