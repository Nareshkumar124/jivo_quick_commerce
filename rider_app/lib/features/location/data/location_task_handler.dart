import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/location_buffer.dart';
import '../domain/location_tracker.dart';
import '../domain/tracking_config.dart';
import '../domain/location_uploader.dart';
import 'fake_location_uploader.dart';
import 'file_point_store.dart';
import 'geolocator_position_source.dart';
import 'location_buffer_file.dart';
import 'location_service_protocol.dart';
import 'service_isolate_api.dart';

/// Entry point of the location service isolate. flutter_foreground_task runs
/// it in its own Flutter engine inside the foreground service, so tracking
/// continues when the activity is destroyed (app swiped away).
@pragma('vm:entry-point')
void startLocationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// Owns the [LocationTracker] and its persisted buffer. This isolate is the
/// only reader and writer of the buffer file.
///
/// Lifecycle (04 §3, agent rule 1): it exists only while the rider is online.
/// The UI starts it when the shift starts and stops it when the rider goes
/// offline or the session ends. If the server says the rider is no longer
/// online (auto-offline), the service stops itself and leaves a marker the
/// app shows on its next start.
class LocationTaskHandler extends TaskHandler {
  LocationTracker? _tracker;
  LocationUploader? _uploader;

  /// The fake (dev `FAKE_API`) has switches for the dev screen.
  FakeLocationUploader? get _fake => switch (_uploader) {
    final FakeLocationUploader fake => fake,
    _ => null,
  };
  LocationTaskSettings _settings = const LocationTaskSettings(
    config: TrackingConfig(),
    mode: TrackingMode.idle,
  );

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('LocationTaskHandler.onStart(starter: ${starter.name})');
    _settings = await LocationTaskSettings.load();
    final bufferFile = await locationBufferFile();
    // POST /rider/locations/ and /rider/heartbeat/ with this isolate's own
    // session (the fake in FAKE_API builds).
    final uploader = await createServiceUploader(
      _settings.api,
      simulateOffline: _settings.simulateOffline,
      simulateServerOffline: _settings.simulateServerOffline,
    );
    final tracker = LocationTracker(
      source: GeolocatorPositionSource(),
      buffer: LocationBuffer(
        store: FilePointStore(bufferFile),
        maxPoints: _settings.config.maxBufferedPoints,
      ),
      uploader: uploader,
      config: _settings.config,
      mode: _settings.mode,
      onStats: (stats) =>
          FlutterForegroundTask.sendDataToMain(LocationMessages.stats(stats)),
      onServerStop: (code) => unawaited(_onServerStop(code)),
    );
    _uploader = uploader;
    _tracker = tracker;
    await tracker.start();
  }

  /// The server no longer tracks this rider: tell the UI (if it is alive),
  /// leave a marker for the next app start, and stop the service, which also
  /// removes the "You're online" notification.
  Future<void> _onServerStop(String code) async {
    debugPrint('LocationTaskHandler: server stopped tracking ($code)');
    await LocationTaskSettings.saveServerStop(code);
    FlutterForegroundTask.sendDataToMain(LocationMessages.serverStop(code));
    await FlutterForegroundTask.stopService();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Not used: the tracker owns its timers (eventAction is nothing()).
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('LocationTaskHandler.onDestroy(isTimeout: $isTimeout)');
    final tracker = _tracker;
    _tracker = null;
    // Stop GPS first; then one bounded attempt to upload what was recorded
    // while online. Anything left stays in the file for the next session.
    await tracker?.stop(flushTimeout: const Duration(seconds: 3));
  }

  @override
  void onReceiveData(Object data) {
    final tracker = _tracker;
    if (tracker == null || data is! Map) return;
    switch (LocationMessages.typeOf(data)) {
      case 'set_mode':
        final mode = TrackingMode.values.byName(data['mode'] as String);
        tracker.setMode(mode);
        _saveSettings(_settings.copyWith(mode: mode));
      case 'simulate_offline':
        final value = data['value'] as bool;
        _fake?.simulateOffline = value;
        _saveSettings(_settings.copyWith(simulateOffline: value));
        if (!value) unawaited(tracker.flush());
      case 'simulate_server_offline':
        final value = data['value'] as bool;
        _fake?.simulateServerOffline = value;
        _saveSettings(_settings.copyWith(simulateServerOffline: value));
        if (value) unawaited(tracker.flush());
      case 'flush':
        unawaited(tracker.flush());
      case 'request_stats':
        FlutterForegroundTask.sendDataToMain(
          LocationMessages.stats(tracker.stats),
        );
    }
  }

  void _saveSettings(LocationTaskSettings settings) {
    _settings = settings;
    unawaited(settings.save());
  }
}
