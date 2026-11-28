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

  /// Whether the system already exempts this app from battery optimisation
  /// (`PowerManager.isIgnoringBatteryOptimizations`). Read only: the app
  /// never asks for the exemption (Play policy). True when the check fails,
  /// so a failed read never nags the rider with the optional tip.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } on Object catch (error) {
      debugPrint('DeviceChannel.isIgnoringBatteryOptimizations: $error');
      return true;
    }
  }

  /// Opens the system list of battery-optimised apps
  /// (`ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, no special permission),
  /// or the app's settings page where that list is missing.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      return await _channel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } on Object catch (error) {
      debugPrint('DeviceChannel.openBatteryOptimizationSettings: $error');
      return false;
    }
  }

  /// Whether this build has a Google Maps API key (T-821, DL-80). A map is
  /// only created when it does; false when the check fails.
  Future<bool> hasMapsKey() async {
    try {
      return await _channel.invokeMethod<bool>('hasMapsKey') ?? false;
    } on Object catch (error) {
      debugPrint('DeviceChannel.hasMapsKey: $error');
      return false;
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

  /// Stops showing the app over the lock screen. Call when an offer alert is
  /// dismissed, accepted or rejected.
  Future<void> releaseLockScreen() =>
      _channel.invokeMethod<void>('releaseLockScreen');
}
