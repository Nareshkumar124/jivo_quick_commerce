import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_channels.dart';
import 'push_messaging.dart';

/// The few FCM calls the app makes. [FirebaseFcmClient] is the real one;
/// tests use a fake.
abstract interface class FcmClient {
  /// Asks for permission to show notifications (Android 13+
  /// `POST_NOTIFICATIONS`, iOS). True when granted (or provisional).
  Future<bool> requestPermission();

  Future<String?> getToken();

  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground (the system
  /// doesn't show them).
  Stream<IncomingPush> get onForegroundMessage;

  /// Data of a system notification tapped while the app was in the
  /// background.
  Stream<Map<String, Object?>> get onMessageOpenedApp;

  /// Data of the system notification that launched the app, if any.
  Future<Map<String, Object?>?> initialMessageData();
}

/// Shows notifications for foreground pushes and owns the channels.
/// [FlutterLocalNotifier] is the real one; tests use a fake.
abstract interface class LocalNotifier {
  /// Prepares the plugin; [onTap] gets the payload of a tapped local
  /// notification while the app runs.
  Future<void> initialize({required void Function(String? payload) onTap});

  /// Creates (or updates the names of) the Android channels.
  Future<void> createChannels(PushChannelTexts texts);

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required PushChannel channel,
    required PushChannelTexts texts,
    required String payload,
  });

  /// The payload of the local notification that launched the app, if any.
  Future<String?> launchPayload();
}

/// Push through Firebase Cloud Messaging (D-19).
///
/// - Background and terminated: FCM notification messages are shown by the
///   system on the channel the server names (manifest default `general`);
///   a tap arrives through [FcmClient.onMessageOpenedApp] or, for a cold
///   start, [FcmClient.initialMessageData].
/// - Foreground: the system shows nothing, so the message is shown as a
///   local notification on [channelFor] with the FCM data as its payload;
///   tapping it routes exactly like a system notification.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({
    required this._fcm,
    required this._local,
    required this._texts,
  });

  final FcmClient _fcm;
  final LocalNotifier _local;
  final PushChannelTexts _texts;

  final _taps = StreamController<Map<String, Object?>>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _initialTaken = false;

  /// Creates the channels and starts showing foreground pushes. Failures
  /// are logged; pushes still register and route.
  Future<void> start() async {
    _subscriptions
      ..add(_fcm.onMessageOpenedApp.listen(_taps.add))
      ..add(_fcm.onForegroundMessage.listen((m) => unawaited(_show(m))));
    try {
      await _local.initialize(
        onTap: (payload) {
          final data = decodePushPayload(payload);
          if (data != null) _taps.add(data);
        },
      );
      await _local.createChannels(_texts);
    } catch (error) {
      debugPrint('Push: local notifications unavailable: $error');
    }
  }

  Future<void> _show(IncomingPush push) async {
    if (!push.hasText) return;
    try {
      await _local.show(
        id: notificationIdFor(push),
        title: push.title ?? '',
        body: push.body ?? '',
        channel: channelFor(push),
        texts: _texts,
        payload: encodePushPayload(push.data),
      );
    } catch (error) {
      debugPrint('Push: could not show a foreground notification: $error');
    }
  }

  @override
  bool get isConfigured => true;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _fcm.requestPermission();
    } catch (error) {
      debugPrint('Push: permission request failed: $error');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (error) {
      // No Play services, offline, or (iOS) no APNs token yet.
      debugPrint('Push: no token: $error');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
    } catch (error) {
      debugPrint('Push: could not delete the token: $error');
    }
  }

  @override
  Stream<Map<String, Object?>> get onNotificationTap => _taps.stream;

  @override
  Future<Map<String, Object?>?> takeInitialNotification() async {
    if (_initialTaken) return null;
    _initialTaken = true;
    try {
      final data = await _fcm.initialMessageData();
      if (data != null) return data;
    } catch (error) {
      debugPrint('Push: no initial message: $error');
    }
    try {
      return decodePushPayload(await _local.launchPayload());
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _taps.close();
  }
}

/// [FcmClient] over `firebase_messaging`. Needs `Firebase.initializeApp()`
/// to have succeeded.
///
/// Uses the FCM registration token (`getToken` / `onTokenRefresh` /
/// `deleteToken`), which firebase_messaging 17 deprecates in favour of
/// Firebase Installation ID "direct send" (`register` / `onRegistered`).
/// The backend contract (`POST /me/devices/ {fcm_token}`, `06 §2.2`) and
/// the server's FCM HTTP v1 sends address registration tokens, which FCM
/// still supports; moving to FIDs needs a backend change first.
class FirebaseFcmClient implements FcmClient {
  FirebaseFcmClient([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static Map<String, Object?> _data(RemoteMessage message) => {
    for (final e in message.data.entries) e.key: e.value,
  };

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      _ => false,
    };
  }

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
      FirebaseMessaging.onMessage.map(
        (m) => IncomingPush(
          messageId: m.messageId,
          title: m.notification?.title,
          body: m.notification?.body,
          androidChannelId: m.notification?.android?.channelId,
          data: _data(m),
        ),
      );

  @override
  Stream<Map<String, Object?>> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_data);

  @override
  Future<Map<String, Object?>?> initialMessageData() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _data(message);
  }
}

/// [LocalNotifier] over `flutter_local_notifications`.
class FlutterLocalNotifier implements LocalNotifier {
  FlutterLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// `res/drawable/ic_stat_jivo.xml` (also the FCM default icon).
  static const _smallIcon = 'ic_stat_jivo';

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        // Permission is asked through FCM at the right moment, never here.
        // TODO(ios): foreground presentation once APNs is set up (D-19).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> createChannels(PushChannelTexts texts) async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        PushChannel.orders.id,
        texts.ordersName,
        description: texts.ordersDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        PushChannel.general.id,
        texts.generalName,
        description: texts.generalDescription,
      ),
    );
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required PushChannel channel,
    required PushChannelTexts texts,
    required String payload,
  }) {
    final orders = channel == PushChannel.orders;
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          orders ? texts.ordersName : texts.generalName,
          channelDescription: orders
              ? texts.ordersDescription
              : texts.generalDescription,
          importance: orders ? Importance.high : Importance.defaultImportance,
          priority: orders ? Priority.high : Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return null;
    return details?.notificationResponse?.payload;
  }
}
