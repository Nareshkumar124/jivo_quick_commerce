import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_point.dart';
import '../domain/position_source.dart';
import '../domain/tracking_config.dart';

/// GPS fixes from geolocator.
///
/// No `foregroundNotificationConfig`: the app's own foreground service
/// (flutter_foreground_task, type "location") keeps the process alive and
/// owns the "You're online" notification. Geolocator's built-in service is
/// not used.
///
/// Provider choice. Geolocator's default Android client (Play services fused
/// provider) first runs a SettingsClient check. In the service isolate there
/// is no Activity, so when that check wants the user to change a setting (for
/// example Google Location Accuracy is off) geolocator reports
/// [LocationServiceDisabledException] even though location is on. Seen on the
/// API 37 emulator in the Phase 0 spike. In that case this source switches to
/// geolocator's LocationManager client for the rest of the session, which
/// uses the platform fused provider on Android 12+ and GPS below.
class GeolocatorPositionSource implements PositionSource {
  GeolocatorPositionSource();

  bool _useLocationManager = false;

  /// Whether the LocationManager fallback is active (for diagnostics).
  bool get usingLocationManager => _useLocationManager;

  @override
  Stream<LocationPoint> positions(TrackingIntervals intervals) async* {
    if (!_useLocationManager) {
      try {
        // `await for` (not `yield*`) so a stream error can be caught here.
        await for (final point in _stream(intervals, locationManager: false)) {
          yield point;
        }
        return;
      } on LocationServiceDisabledException {
        if (!await Geolocator.isLocationServiceEnabled()) rethrow;
        debugPrint(
          'GeolocatorPositionSource: fused settings check failed without an '
          'Activity; switching to LocationManager',
        );
        _useLocationManager = true;
      }
    }
    yield* _stream(intervals, locationManager: true);
  }

  static Stream<LocationPoint> _stream(
    TrackingIntervals intervals, {
    required bool locationManager,
  }) {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: intervals.sample,
      forceLocationManager: locationManager,
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => LocationPoint(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: p.accuracy,
        speed: p.hasSpeed ? p.speed : null,
        heading: p.hasHeading ? p.heading : null,
        recordedAt: p.timestamp,
      ),
    );
  }
}
