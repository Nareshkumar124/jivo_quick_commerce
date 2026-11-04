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

  final TrackingConfig config;
  final TrackingMode mode;

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
    bool? simulateOffline,
    bool? simulateServerOffline,
  }) => LocationTaskSettings(
    config: config ?? this.config,
    mode: mode ?? this.mode,
    simulateOffline: simulateOffline ?? this.simulateOffline,
    simulateServerOffline: simulateServerOffline ?? this.simulateServerOffline,
    api: api,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'mode': mode.name,
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
  static Map<String, Object> setMode(TrackingMode mode) => {
    _type: 'set_mode',
    'mode': mode.name,
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
