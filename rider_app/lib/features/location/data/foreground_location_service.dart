import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../domain/location_service_client.dart';
import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';
import 'location_service_protocol.dart';
import 'location_task_handler.dart';

/// Starts and stops the Android foreground service (type `location`) that
/// runs [LocationTaskHandler], and relays its stats to the UI.
class ForegroundLocationService implements LocationServiceClient {
  static const _serviceId = 4201;
  static const _channelId = 'rider_online';
  static const _iconMetaData = 'in.jivo.rider.ONLINE_NOTIFICATION_ICON';

  final _stats = StreamController<TrackerStats>.broadcast();
  bool _listening = false;

  @override
  Stream<TrackerStats> get stats {
    if (!_listening) {
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _listening = true;
    }
    return _stats.stream;
  }

  void _onTaskData(Object data) {
    final stats = LocationMessages.parseStats(data);
    if (stats != null) _stats.add(stats);
  }

  @override
  Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  @override
  Future<void> start({
    required TrackingConfig config,
    required TrackingMode mode,
    required bool simulateOffline,
    required OnlineNotificationText text,
  }) async {
    if (await FlutterForegroundTask.isRunningService) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: text.channelName,
        channelDescription: text.channelDescription,
        // Persistent and silent: it is a status, not an alert.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        // Location only while online: never start on boot or after an update.
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // Restart if the system kills the service while the rider is online.
        allowAutoRestart: true,
        // Keep tracking when the rider swipes the app away.
        stopWithTask: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    await LocationTaskSettings(
      config: config,
      mode: mode,
      simulateOffline: simulateOffline,
    ).save();

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: text.title,
      notificationText: text.body,
      notificationIcon: const NotificationIcon(metaDataName: _iconMetaData),
      notificationInitialRoute: '/',
      callback: startLocationTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      throw LocationServiceException(result.error);
    }
  }

  @override
  Future<void> stop() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestFailure) {
      throw LocationServiceException(result.error);
    }
  }

  @override
  void setMode(TrackingMode mode) =>
      FlutterForegroundTask.sendDataToTask(LocationMessages.setMode(mode));

  @override
  void setSimulateOffline(bool value) => FlutterForegroundTask.sendDataToTask(
    LocationMessages.simulateOffline(value),
  );

  @override
  void flush() => FlutterForegroundTask.sendDataToTask(LocationMessages.flush);

  @override
  void requestStats() =>
      FlutterForegroundTask.sendDataToTask(LocationMessages.requestStats);
}
