import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this build can show a Mappls map (D-03).
///
/// A map is only created when the Mappls SDK config (`<appId>.a.olf` and
/// `.a.conf`, linked by `tool/setup_mappls.sh`) was built into the app and
/// passes the SDK's own config check. Android asks `MainActivity`
/// (`prepare`), which runs that check off the main thread and only then
/// registers the Mappls plugin: the SDK never starts at app launch, so a
/// missing or unregistered config can't crash the app (see README). Call
/// this only when a screen needs a map. iOS reports false until its config
/// (`.i.olf`/`.i.conf`) is added to the Runner target.
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
