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

  /// Android 14+: whether this app may show full-screen intents. Play revokes
  /// the permission by default for apps that are not calling/alarm apps.
  /// Always true below Android 14.
  Future<bool> canUseFullScreenIntent() async =>
      await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;

  /// Opens the system page where the rider can allow full-screen alerts.
  Future<bool> openFullScreenIntentSettings() async =>
      await _channel.invokeMethod<bool>('openFullScreenIntentSettings') ??
      false;

  /// Stops showing the app over the lock screen. Call when an offer alert is
  /// dismissed, accepted or rejected.
  Future<void> releaseLockScreen() =>
      _channel.invokeMethod<void>('releaseLockScreen');
}
