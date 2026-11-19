import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this build can show a Google map (DL-80).
///
/// Android asks `MainActivity` (`prepare`), which reports whether the build
/// injected a Maps API key into the manifest (README "Google Maps key").
/// Without one no map is ever created and screens show their fallback.
/// iOS reports false until an iOS key is configured.
abstract interface class MapsAvailability {
  Future<bool> isAvailable();
}

class PlatformMapsAvailability implements MapsAvailability {
  const PlatformMapsAvailability();

  static const _channel = MethodChannel('in.jivo.quick/maps');

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('prepare') ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// For tests: no platform view is ever created unless [available].
class FakeMapsAvailability implements MapsAvailability {
  const FakeMapsAvailability({this.available = false});

  final bool available;

  @override
  Future<bool> isAvailable() async => available;
}
