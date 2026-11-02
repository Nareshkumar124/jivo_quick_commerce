import 'package:geolocator/geolocator.dart';

/// Why the device position couldn't be read.
enum LocationFailure { servicesOff, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  @override
  String toString() => 'LocationException($reason)';
}

typedef GeoPoint = ({double lat, double lng});

/// The device position, with the permission flow. Phase 1 uses it instead
/// of the map pin (Phase 2).
abstract interface class DeviceLocation {
  /// Asks for permission if needed. Throws [LocationException].
  Future<GeoPoint> current();

  /// Opens the app's settings (permission) or the location settings.
  Future<void> openSettings(LocationFailure reason);
}

class GeolocatorDeviceLocation implements DeviceLocation {
  const GeolocatorDeviceLocation();

  @override
  Future<GeoPoint> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.servicesOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(LocationFailure.denied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationFailure.deniedForever);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        break;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  @override
  Future<void> openSettings(LocationFailure reason) async {
    if (reason == LocationFailure.servicesOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

/// For tests and `FAKE_API` runs.
class FakeDeviceLocation implements DeviceLocation {
  FakeDeviceLocation({
    this.point = (lat: 28.613939, lng: 77.209023),
    this.failure,
  });

  GeoPoint point;
  LocationFailure? failure;
  final List<LocationFailure> settingsOpened = [];

  @override
  Future<GeoPoint> current() async {
    final reason = failure;
    if (reason != null) throw LocationException(reason);
    return point;
  }

  @override
  Future<void> openSettings(LocationFailure reason) async =>
      settingsOpened.add(reason);
}
