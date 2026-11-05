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

  /// Dev only: make the fake uploader answer like a server that already
  /// auto-offlined the rider.
  void setSimulateServerOffline(bool value);

  void flush();

  void requestStats();

  /// Stats pushed by the service isolate.
  Stream<TrackerStats> get stats;

  /// Error codes with which the server stopped tracking (for example
  /// `RIDER_OFFLINE` after an auto-offline). The service has already stopped
  /// itself when one arrives.
  Stream<String> get serverStops;

  /// A server stop that happened while the app was not running, or null.
  /// Clears it.
  Future<String?> takeServerStop();
}
