import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this build can show a Mappls map (D-03).
///
/// A map is only created when the Mappls SDK config (`<appId>.a.olf` and
/// `.a.conf`, linked by `tool/setup_mappls.sh`) was built into the app;
/// without it the SDK cannot authenticate. Android asks `MainActivity`,
/// which looks for the resource and asset the mappls_gl Gradle plugin
/// generates from the config (see README). iOS reports false until its
/// config (`.i.olf`/`.i.conf`) is added to the Runner target.
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
      return await _channel.invokeMethod<bool>('isConfigured') ?? false;
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
