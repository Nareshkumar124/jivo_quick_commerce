import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../shared/platform/device_channel.dart';

/// The high-priority "new order offer" notification channel (04 §2.4):
/// max importance, sound on the alarm stream, vibration, and a full-screen
/// intent so the offer opens over the lock screen.
///
/// Phase 0 spike: only a local test offer is shown, from the dev debug screen.
/// In P5 the same channel is used for the FCM high-priority data message.
class OfferAlertNotifications {
  OfferAlertNotifications({
    FlutterLocalNotificationsPlugin? plugin,
    this._device = const DeviceChannel(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Channel settings (importance, sound, vibration) cannot be changed after
  /// the channel is created on a device. Bump the suffix to change them.
  static const channelId = 'offer_alerts_v1';

  /// `MainActivity` shows over the lock screen only for this payload prefix.
  static const payloadPrefix = 'offer:';
  static const testPayload = '${payloadPrefix}test';
  static const testNotificationId = 9001;

  /// Offers expire after 30 s (04 §2.4). The real offer uses the server's
  /// `expires_at` instead.
  static const offerTimeout = Duration(seconds: 30);

  static const _smallIcon = 'ic_stat_rider';

  final FlutterLocalNotificationsPlugin _plugin;
  final DeviceChannel _device;

  static bool isOfferPayload(String? payload) =>
      payload != null && payload.startsWith(payloadPrefix);

  /// Creates the channel and registers [onOfferSelected] for taps and
  /// full-screen launches while the app is running. Returns the offer payload
  /// if the app process was started by an offer alert, otherwise null.
  Future<String?> initialize({
    required String channelName,
    required String channelDescription,
    required void Function(String payload) onOfferSelected,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (isOfferPayload(payload)) onOfferSelected(payload!);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        vibrationPattern: _vibration,
        // Alarm stream: rings at alarm volume, also when the ringer is on
        // vibrate. A custom loud ringtone (res/raw) is a P5 item.
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        isOfferPayload(payload)) {
      return payload;
    }
    return null;
  }

  /// Shows a fake offer through the real channel, to prove the full-screen
  /// path. Dev flavor only.
  Future<void> showTestOffer({
    required String title,
    required String body,
    required String channelName,
  }) => _plugin.show(
    id: testNotificationId,
    title: title,
    body: body,
    payload: testPayload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        // Matches the alarm audio stream. Open question for P5: alarm vs
        // call category (DND behaviour differs).
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        vibrationPattern: _vibration,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        timeoutAfter: offerTimeout.inMilliseconds,
        // FLAG_INSISTENT: repeat sound and vibration until the rider acts.
        additionalFlags: Int32List.fromList(const [4]),
      ),
    ),
  );

  /// The real offer alert: same channel and flags as [showTestOffer], with
  /// the offer's own payload (`offer:<id>`) and a timeout matching the time
  /// the offer has left.
  Future<void> showOffer({
    required int offerId,
    required String title,
    required String body,
    required String channelName,
    required Duration timeout,
  }) => _plugin.show(
    id: offerNotificationId,
    title: title,
    body: body,
    payload: '$payloadPrefix$offerId',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        vibrationPattern: _vibration,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        timeoutAfter: timeout.inMilliseconds.clamp(1000, 60000),
        additionalFlags: Int32List.fromList(const [4]),
      ),
    ),
  );

  /// The notification id of real offers (one offer at a time).
  static const offerNotificationId = 9002;

  /// Removes the alert and stops showing the app over the lock screen.
  Future<void> dismiss({int id = testNotificationId}) async {
    await _plugin.cancel(id: id);
    try {
      await _device.releaseLockScreen();
    } on Object catch (error) {
      debugPrint('OfferAlertNotifications: releaseLockScreen failed: $error');
    }
  }

  static final _vibration = Int64List.fromList(const [0, 800, 400, 800]);
}
