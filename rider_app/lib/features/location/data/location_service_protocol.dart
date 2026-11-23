import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';
import 'service_isolate_api.dart';

/// Settings the service isolate starts with. Saved before the service starts
/// (and on every change), so a restart by the system resumes with the same
/// mode and intervals.
class LocationTaskSettings {
  const LocationTaskSettings({
    required this.config,
    required this.mode,
    this.taskId,
    this.simulateOffline = false,
    this.simulateServerOffline = false,
    this.api = ServiceApiSettings.fake,
  });

  factory LocationTaskSettings.fromJson(Map<String, dynamic> json) =>
      LocationTaskSettings(
        config: TrackingConfig.fromJson(
          (json['config'] as Map).cast<String, dynamic>(),
        ),
        mode: TrackingMode.values.byName(json['mode'] as String),
        taskId: json['task_id'] as int?,
        simulateOffline: json['simulate_offline'] as bool? ?? false,
        simulateServerOffline:
            json['simulate_server_offline'] as bool? ?? false,
        api: json['api'] is Map
            ? ServiceApiSettings.fromJson(
                (json['api'] as Map).cast<String, dynamic>(),
              )
            : ServiceApiSettings.fake,
      );

  static const _storageKey = 'rider.location.settings';

  /// Set by the service when the server stopped tracking (for example the
  /// rider was auto-offlined), so the app can tell the rider even if it was
  /// not running at that moment. Read and cleared with [takeServerStop].
  static const _serverStopKey = 'rider.location.server_stop';

  /// Every key kept in SharedPreferences (through flutter_foreground_task)
  /// for the online service. Rider-session state, so sign-out removes them
  /// ([clearStored]): the next rider on this phone must not see the last
  /// one's "You were set offline" (P8 security audit).
  static const storedKeys = [_storageKey, _serverStopKey];

  /// Removes [storedKeys]. Only while the service is stopped. [remove] is
  /// replaced in tests.
  static Future<void> clearStored({
    Future<bool> Function({required String key}) remove =
        FlutterForegroundTask.removeData,
  }) async {
    for (final key in storedKeys) {
      await remove(key: key);
    }
  }

  final TrackingConfig config;
  final TrackingMode mode;

  /// The task the app thinks is active (sent with the batches, T-821), so
  /// a service restarted by the system keeps sending it.
  final int? taskId;

  /// Dev only: makes the fake uploader fail like a dropped network.
  final bool simulateOffline;

  /// Dev only: makes the fake uploader answer like a server that already
  /// auto-offlined the rider.
  final bool simulateServerOffline;

  /// Which backend the service uploads to.
  final ServiceApiSettings api;

  LocationTaskSettings copyWith({
    TrackingConfig? config,
    TrackingMode? mode,
    int? taskId,
    bool clearTaskId = false,
    bool? simulateOffline,
    bool? simulateServerOffline,
  }) => LocationTaskSettings(
    config: config ?? this.config,
    mode: mode ?? this.mode,
    taskId: clearTaskId ? null : taskId ?? this.taskId,
    simulateOffline: simulateOffline ?? this.simulateOffline,
    simulateServerOffline: simulateServerOffline ?? this.simulateServerOffline,
    api: api,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'mode': mode.name,
    'task_id': taskId,
    'simulate_offline': simulateOffline,
    'simulate_server_offline': simulateServerOffline,
    'api': api.toJson(),
  };

  static Future<void> saveServerStop(String code) =>
      FlutterForegroundTask.saveData(key: _serverStopKey, value: code);

  /// The code of a server stop the app has not shown yet, or null. Clears it.
  static Future<String?> takeServerStop() async {
    final code = await FlutterForegroundTask.getData<String>(
      key: _serverStopKey,
    );
    if (code != null) {
      await FlutterForegroundTask.removeData(key: _serverStopKey);
    }
    return code;
  }

  Future<void> save() => FlutterForegroundTask.saveData(
    key: _storageKey,
    value: jsonEncode(toJson()),
  );

  static Future<LocationTaskSettings> load() async {
    final raw = await FlutterForegroundTask.getData<String>(key: _storageKey);
    if (raw == null) {
      return const LocationTaskSettings(
        config: TrackingConfig(),
        mode: TrackingMode.idle,
      );
    }
    return LocationTaskSettings.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}

/// Messages between the UI isolate and the location service isolate. Only
/// primitives, lists and maps can cross isolates.
abstract final class LocationMessages {
  static const _type = 'type';

  // UI -> service
  static Map<String, Object?> setMode(TrackingMode mode, {int? taskId}) => {
    _type: 'set_mode',
    'mode': mode.name,
    'task_id': taskId,
  };
  static Map<String, Object> simulateOffline(bool value) => {
    _type: 'simulate_offline',
    'value': value,
  };
  static Map<String, Object> simulateServerOffline(bool value) => {
    _type: 'simulate_server_offline',
    'value': value,
  };
  static const flush = {_type: 'flush'};
  static const requestStats = {_type: 'request_stats'};

  // service -> UI
  static Map<String, Object?> stats(TrackerStats stats) => {
    _type: 'stats',
    'stats': stats.toJson(),
  };

  /// Sent last by the service's `onDestroy`, after the final flush and the
  /// buffer's last write: nothing writes the buffer file after it.
  static const destroyed = {_type: 'destroyed'};

  static bool isDestroyed(Object data) => typeOf(data) == 'destroyed';

  /// The server linked the points to another task (`active_task_id`,
  /// T-821): the app re-reads `tasks/current/`.
  static Map<String, Object?> taskMismatch(int? serverTaskId) => {
    _type: 'task_mismatch',
    'task_id': serverTaskId,
  };

  /// Whether [data] is a `task_mismatch` message.
  static bool isTaskMismatch(Object data) => typeOf(data) == 'task_mismatch';

  static Map<String, Object> serverStop(String code) => {
    _type: 'server_stop',
    'code': code,
  };

  /// The code of a `server_stop` message, or null for other messages.
  static String? parseServerStop(Object data) {
    if (typeOf(data) != 'server_stop') return null;
    final code = (data as Map)['code'];
    return code is String ? code : null;
  }

  static String? typeOf(Object data) =>
      data is Map ? data[_type] as String? : null;

  static TrackerStats? parseStats(Object data) {
    if (typeOf(data) != 'stats') return null;
    final stats = (data as Map)['stats'];
    return stats is Map
        ? TrackerStats.fromJson(stats.cast<String, dynamic>())
        : null;
  }
}
