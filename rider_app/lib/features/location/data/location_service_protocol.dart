import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';

/// Settings the service isolate starts with. Saved before the service starts
/// (and on every change), so a restart by the system resumes with the same
/// mode and intervals.
class LocationTaskSettings {
  const LocationTaskSettings({
    required this.config,
    required this.mode,
    this.simulateOffline = false,
  });

  factory LocationTaskSettings.fromJson(Map<String, dynamic> json) =>
      LocationTaskSettings(
        config: TrackingConfig.fromJson(
          (json['config'] as Map).cast<String, dynamic>(),
        ),
        mode: TrackingMode.values.byName(json['mode'] as String),
        simulateOffline: json['simulate_offline'] as bool? ?? false,
      );

  static const _storageKey = 'rider.location.settings';

  final TrackingConfig config;
  final TrackingMode mode;

  /// Dev only: makes the fake uploader fail like a dropped network.
  final bool simulateOffline;

  LocationTaskSettings copyWith({
    TrackingConfig? config,
    TrackingMode? mode,
    bool? simulateOffline,
  }) => LocationTaskSettings(
    config: config ?? this.config,
    mode: mode ?? this.mode,
    simulateOffline: simulateOffline ?? this.simulateOffline,
  );

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'mode': mode.name,
    'simulate_offline': simulateOffline,
  };

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
  static const flush = {_type: 'flush'};
  static const requestStats = {_type: 'request_stats'};

  // service -> UI
  static Map<String, Object?> stats(TrackerStats stats) => {
    _type: 'stats',
    'stats': stats.toJson(),
  };

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
