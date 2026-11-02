import 'tracker_stats.dart';
import 'tracking_config.dart';

/// Localised text for the persistent "You're online" notification. The
/// service isolate has no BuildContext, so the UI passes it in.
class OnlineNotificationText {
  const OnlineNotificationText({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.cause);

  final Object cause;

  @override
  String toString() => 'LocationServiceException: $cause';
}

/// UI-side handle on the online location service. Going online starts it,
/// going offline stops it (04 §2.3, §3).
abstract interface class LocationServiceClient {
  Future<bool> isRunning();

  /// Starts the foreground service with its persistent notification. No-op if
  /// it is already running. Throws [LocationServiceException] on failure.
  Future<void> start({
    required TrackingConfig config,
    required TrackingMode mode,
    required bool simulateOffline,
    required OnlineNotificationText text,
  });

  /// Stops the service and with it all location updates.
  Future<void> stop();

  void setMode(TrackingMode mode);

  /// Dev only: make the fake uploader fail like a dropped network.
  void setSimulateOffline(bool value);

  void flush();

  void requestStats();

  /// Stats pushed by the service isolate.
  Stream<TrackerStats> get stats;
}
