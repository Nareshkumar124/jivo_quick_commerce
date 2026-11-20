import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this build can show a Google map (DL-80).
///
/// Android and iOS ask the native side over `in.jivo.quick/maps` (`prepare`):
/// `MainActivity` reports whether the build injected a Maps API key into the
/// manifest, and `AppDelegate.swift` whether Info.plist had a `GMSApiKey`
/// that it handed to `GMSServices.provideAPIKey` (README "Google Maps key").
/// Without a key, on web and other platforms, and on any channel error, no
/// map is ever created and screens show their fallback.
abstract interface class MapsAvailability {
  Future<bool> isAvailable();
}

class PlatformMapsAvailability implements MapsAvailability {
  const PlatformMapsAvailability();

  static const _channel = MethodChannel('in.jivo.quick/maps');

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
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
