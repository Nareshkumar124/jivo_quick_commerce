import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
  });

  final int sdkInt;
  final String manufacturer;
  final String model;
}

/// Dart side of `MainActivity`'s "in.jivo.rider/device" channel: small
/// Android facts and actions that no plugin in the stack covers.
class DeviceChannel {
  const DeviceChannel();

  static const _channel = MethodChannel('in.jivo.rider/device');

  Future<DeviceInfo> deviceInfo() async {
    final map = await _channel.invokeMapMethod<String, Object?>(
      'getDeviceInfo',
    );
    return DeviceInfo(
      sdkInt: (map?['sdkInt'] as int?) ?? 0,
      manufacturer: (map?['manufacturer'] as String?) ?? '',
      model: (map?['model'] as String?) ?? '',
    );
  }

  /// Android 14+: whether this app may show full-screen intents
  /// (`NotificationManager.canUseFullScreenIntent()`, or the
  /// USE_FULL_SCREEN_INTENT app-op allowed). Play revokes the permission by
  /// default for apps that are not calling/alarm apps. Always true below
  /// Android 14, and when the check itself fails: it is advisory, and a
  /// failed check must never send the rider to that settings page.
  Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } on Object catch (error) {
      debugPrint('DeviceChannel.canUseFullScreenIntent: $error');
      return true;
    }
  }

  /// The location app-op modes (`coarse`, `fine`): "allowed",
  /// "foreground", "ignored", "errored" or "default". Null when they can't
  /// be read (the runtime permission then decides alone).
  Future<Map<String, Object?>?> locationOps() async {
    try {
      return await _channel.invokeMapMethod<String, Object?>('locationOps');
    } on Object catch (error) {
      debugPrint('DeviceChannel.locationOps: $error');
      return null;
    }
  }

  /// Rings the default alarm tone (looping) and vibrates, in the app: the
  /// offer alert while the offer screen is in front, where the heads-up
  /// notification would cover it. [stopOfferRinging] ends it.
  Future<void> startOfferRinging() =>
      _channel.invokeMethod<void>('startOfferRinging');

  Future<void> stopOfferRinging() =>
      _channel.invokeMethod<void>('stopOfferRinging');

  /// Opens the system page where the rider can allow full-screen alerts.
  Future<bool> openFullScreenIntentSettings() async =>
      await _channel.invokeMethod<bool>('openFullScreenIntentSettings') ??
      false;

  /// Stops showing the app over the lock screen. Call when an offer alert is
  /// dismissed, accepted or rejected.
  Future<void> releaseLockScreen() =>
      _channel.invokeMethod<void>('releaseLockScreen');
}
