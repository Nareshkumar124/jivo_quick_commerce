import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jivo_core/helpers.dart';

import '../../../shared/platform/device_channel.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../../offers/domain/delivery_offer.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';

/// Navigation through a generic `geo:` intent, so the Mappls app (DL-29) or
/// any installed maps app handles it. No embedded navigation in v1.
///
/// Option for later: try the Mappls app's own navigation deep link first
/// (format to confirm with MapmyIndia), then fall back to `geo:`.
class GeoIntentNavigationLauncher implements NavigationLauncher {
  const GeoIntentNavigationLauncher(this._opener);

  final UrlOpener _opener;

  /// `geo:0,0?q=lat,lng(label)`: a pin at the destination; the maps app
  /// offers directions from there.
  static Uri geoUri(GeoPoint to, String label) =>
      Uri.parse('geo:0,0?q=${to.lat},${to.lng}(${Uri.encodeComponent(label)})');

  @override
  Future<bool> navigateTo(GeoPoint destination, {required String label}) =>
      _opener.open(geoUri(destination, label));
}

/// One fresh, accurate fix from the UI isolate (the tracking service runs in
/// its own isolate). Falls back to the last known position, if it is at
/// most a minute old, when a fresh fix takes too long.
class GeolocatorCurrentLocation implements CurrentLocationReader {
  const GeolocatorCurrentLocation();

  static const _maxLastKnownAge = Duration(seconds: 60);

  @override
  Future<GeoPoint> current() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on Object catch (error) {
      debugPrint('GeolocatorCurrentLocation: ${error.runtimeType}');
      final last = await Geolocator.getLastKnownPosition();
      // An old fix could pass or fail the geofence for the wrong place.
      if (last == null ||
          DateTime.now().difference(last.timestamp) > _maxLastKnownAge) {
        throw const LocationUnavailable();
      }
      return GeoPoint(last.latitude, last.longitude);
    }
  }
}

/// Rings through the Phase 0 offer channel (alarm stream, insistent,
/// full-screen intent over the lock screen).
class NotificationOfferAlerter implements OfferAlerter {
  const NotificationOfferAlerter(
    this._alerts, {
    required this.channelName,
    this._device = const DeviceChannel(),
  });

  final OfferAlertNotifications _alerts;
  final DeviceChannel _device;
  final String channelName;

  @override
  Future<void> ring(
    DeliveryOffer offer, {
    required String title,
    required String body,
    required Duration timeout,
    required bool inForeground,
  }) async {
    if (inForeground) {
      // The offer screen is in front: ring in the app, no heads-up on top
      // of it. Cancelling keeps the lock-screen flags (a full-screen launch
      // still shows the offer over the lock screen).
      try {
        await _alerts.cancelOffer();
      } on Object catch (error) {
        debugPrint('NotificationOfferAlerter.cancel: ${error.runtimeType}');
      }
      try {
        await _device.startOfferRinging();
      } on Object catch (error) {
        debugPrint('NotificationOfferAlerter.inApp: ${error.runtimeType}');
      }
      return;
    }
    await _stopInApp();
    try {
      await _alerts.showOffer(
        offerId: offer.id,
        title: title,
        body: body,
        channelName: channelName,
        timeout: timeout,
      );
    } on Object catch (error) {
      debugPrint('NotificationOfferAlerter.ring: ${error.runtimeType}');
    }
  }

  Future<void> _stopInApp() async {
    try {
      await _device.stopOfferRinging();
    } on Object catch (error) {
      debugPrint('NotificationOfferAlerter.stopInApp: ${error.runtimeType}');
    }
  }

  @override
  Future<void> stop() async {
    await _stopInApp();
    try {
      await _alerts.dismiss(id: OfferAlertNotifications.offerNotificationId);
    } on Object catch (error) {
      debugPrint('NotificationOfferAlerter.stop: ${error.runtimeType}');
    }
  }
}
