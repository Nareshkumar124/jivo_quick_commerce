import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/push_messaging.dart';
import 'push_channels.dart';

/// The few FCM calls the app makes. [FirebaseFcmClient] is the real one;
/// tests use a fake.
abstract interface class FcmClient {
  Future<String?> getToken();

  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground (the system
  /// doesn't show them).
  Stream<IncomingPush> get onForegroundMessage;

  /// Data of a system notification tapped while the app was in the
  /// background.
  Stream<Map<String, String>> get onMessageOpenedApp;

  /// Data of the system notification that launched the app, if any.
  Future<Map<String, String>?> initialMessageData();
}

/// Creates the push channels and shows foreground pushes.
/// [FlutterLocalPushNotifier] is the real one; tests use a fake.
///
/// It never calls `FlutterLocalNotificationsPlugin.initialize`: the plugin
/// has one tap callback per process, owned by [OfferAlertNotifications]
/// (bootstrap), which hands push payloads ([pushPayloadPrefix]) to
/// [FirebasePushMessaging.onLocalNotificationTap].
abstract interface class PushNotifier {
  /// Creates (or updates the names of) the Android push channels.
  Future<void> createChannels(RiderPushChannelTexts texts);

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required RiderPushChannel channel,
    required RiderPushChannelTexts texts,
    required String payload,
  });
}

/// Push through Firebase Cloud Messaging (D-19).
///
/// - Background and terminated: FCM notification messages are shown by the
///   system on the channel the server names (manifest default `general`);
///   a tap arrives through [FcmClient.onMessageOpenedApp] or, for a cold
///   start, [FcmClient.initialMessageData]. A data-only `offer.new` rings
///   the full-screen offer alarm through the background handler
///   (`push_background.dart`).
/// - Foreground: every message goes to [messages] (the handler refreshes
///   the offer, task, cash or ticket). The system shows nothing, so a
///   message with text is also shown as a local notification on
///   [channelForPush], except offers: the in-app offer screen and its alarm
///   ([OfferAlertNotifications]) are the foreground path. Tapping it routes
///   exactly like a system notification.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({
    required this._fcm,
    required this._notifier,
    required this._texts,
  });

  final FcmClient _fcm;
  final PushNotifier _notifier;
  final RiderPushChannelTexts _texts;

  final _messages = StreamController<PushMessage>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _initialTaken = false;
  Map<String, String>? _localLaunch;

  /// Creates the channels and starts listening. Failures of the local
  /// notifications are logged; pushes still register and route.
  Future<void> start() async {
    _subscriptions
      ..add(
        _fcm.onMessageOpenedApp.listen(
          (data) => _messages.add(PushMessage(data, openedApp: true)),
        ),
      )
      ..add(_fcm.onForegroundMessage.listen(_onForeground));
    try {
      await _notifier.createChannels(_texts);
    } on Object catch (error) {
      debugPrint('Push: channels not created: ${error.runtimeType}');
    }
  }

  void _onForeground(IncomingPush push) {
    _messages.add(PushMessage(push.data));
    if (!push.hasText || push.isOffer) return;
    unawaited(_show(push));
  }

  Future<void> _show(IncomingPush push) async {
    try {
      await _notifier.show(
        id: notificationIdFor(push),
        title: push.title ?? '',
        body: push.body ?? '',
        channel: channelForPush(push),
        texts: _texts,
        payload: encodePushPayload(push.data),
      );
    } on Object catch (error) {
      debugPrint('Push: foreground notification failed: ${error.runtimeType}');
    }
  }

  /// A local push notification ([encodePushPayload]) was tapped while the
  /// app ran. Other payloads (the offer alarm's) are ignored.
  void onLocalNotificationTap(String? payload) {
    final data = decodePushPayload(payload);
    if (data != null) _messages.add(PushMessage(data, openedApp: true));
  }

  /// The payload of the local notification that started the app (read by
  /// [OfferAlertNotifications.initialize] at start-up).
  void setLocalLaunchPayload(String? payload) {
    _localLaunch = decodePushPayload(payload);
  }

  @override
  bool get isAvailable => true;

  @override
  Future<String?> token() async {
    try {
      return await _fcm.getToken();
    } on Object catch (error) {
      // No Play services, offline, ...
      debugPrint('Push: no token: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get messages => _messages.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    if (_initialTaken) return null;
    _initialTaken = true;
    try {
      final data = await _fcm.initialMessageData();
      if (data != null) return PushMessage(data, openedApp: true);
    } on Object catch (error) {
      debugPrint('Push: no initial message: ${error.runtimeType}');
    }
    final local = _localLaunch;
    _localLaunch = null;
    return local == null ? null : PushMessage(local, openedApp: true);
  }

  @override
  Future<bool> deleteToken() async {
    try {
      await _fcm.deleteToken();
      return true;
    } on Object catch (error) {
      debugPrint('Push: token not deleted: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _messages.close();
  }
}

/// The FCM `data` part as string pairs (FCM data values are strings).
Map<String, String> fcmData(RemoteMessage message) => {
  for (final e in message.data.entries)
    if (e.value != null) e.key: '${e.value}',
};

/// The message as [IncomingPush] (foreground and background isolate).
IncomingPush incomingPush(RemoteMessage m) => IncomingPush(
  messageId: m.messageId,
  title: m.notification?.title,
  body: m.notification?.body,
  androidChannelId: m.notification?.android?.channelId,
  data: fcmData(m),
);

/// [FcmClient] over `firebase_messaging`. Needs `Firebase.initializeApp()`
/// to have succeeded.
///
/// Uses the FCM registration token (`getToken` / `onTokenRefresh` /
/// `deleteToken`), which firebase_messaging 17 deprecates in favour of
/// Firebase Installation ID "direct send" (`register` / `onRegistered`).
/// The backend contract (`POST /me/devices/ {fcm_token}`, 06 §2.1) and the
/// server's FCM HTTP v1 sends address registration tokens, which FCM still
/// supports; moving to FIDs needs a backend change first (same as
/// customer_app).
class FirebaseFcmClient implements FcmClient {
  FirebaseFcmClient([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  // ignore: deprecated_member_use, registration tokens (see the class doc).
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use, registration tokens (see the class doc).
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  // ignore: deprecated_member_use, registration tokens (see the class doc).
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<IncomingPush> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(incomingPush);

  @override
  Stream<Map<String, String>> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(fcmData);

  @override
  Future<Map<String, String>?> initialMessageData() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : fcmData(message);
  }
}

/// [PushNotifier] over `flutter_local_notifications`.
class FlutterLocalPushNotifier implements PushNotifier {
  FlutterLocalPushNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// `res/drawable/ic_stat_rider.xml` (also the FCM default icon).
  static const _smallIcon = 'ic_stat_rider';

  static final _offerVibration = Int64List.fromList(const [0, 800, 400, 800]);

  static Importance _importance(RiderPushChannel channel) => switch (channel) {
    RiderPushChannel.offers => Importance.max,
    RiderPushChannel.orders => Importance.high,
    RiderPushChannel.general => Importance.defaultImportance,
  };

  static Priority _priority(RiderPushChannel channel) => switch (channel) {
    RiderPushChannel.offers => Priority.max,
    RiderPushChannel.orders => Priority.high,
    RiderPushChannel.general => Priority.defaultPriority,
  };

  @override
  Future<void> createChannels(RiderPushChannelTexts texts) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    for (final channel in RiderPushChannel.values) {
      final offers = channel == RiderPushChannel.offers;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          texts.nameOf(channel),
          description: texts.descriptionOf(channel),
          importance: _importance(channel),
          vibrationPattern: offers ? _offerVibration : null,
        ),
      );
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required RiderPushChannel channel,
    required RiderPushChannelTexts texts,
    required String payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        texts.nameOf(channel),
        channelDescription: texts.descriptionOf(channel),
        icon: _smallIcon,
        importance: _importance(channel),
        priority: _priority(channel),
        // Task and cash texts carry order numbers and amounts: hidden on a
        // secure lock screen. Offers are public (04 §2.4), but are never
        // shown here (the offer alarm is their foreground path).
        visibility: channel == RiderPushChannel.offers
            ? NotificationVisibility.public
            : NotificationVisibility.private,
        styleInformation: BigTextStyleInformation(body),
      ),
    ),
  );
}
