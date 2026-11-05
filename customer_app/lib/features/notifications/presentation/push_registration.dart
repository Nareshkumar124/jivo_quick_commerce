import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../data/device_repository.dart';
import '../data/push_messaging.dart';

/// Keeps this device's push token registered with the server
/// (`POST /me/devices/`): on sign-in, on every app start while signed in
/// (which also covers an app-version change) and on every token refresh.
///
/// Best effort: a failed call is retried at the next trigger and never
/// blocks the user. Without a push provider ([PushMessaging.isConfigured]
/// false) it does nothing.
class PushRegistrar {
  PushRegistrar({
    required this.messaging,
    required this.devices,
    required this.clientInfo,
    required this.session,
  });

  final PushMessaging messaging;
  final DeviceRepository devices;
  final ClientInfo clientInfo;
  final SessionManager session;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _permissionAsked = false;
  String? _registered;
  String? _token;
  Future<void>? _running;

  /// The token last read from the push provider (sent on logout so the
  /// server stops pushing to this device).
  String? get token => _token;

  /// The token registered for the current session, if any.
  @visibleForTesting
  String? get registered => _registered;

  /// The version sent to the server: `1.0.0` or `1.0.0+12`.
  String get appVersion => clientInfo.buildNumber.isEmpty
      ? clientInfo.appVersion
      : '${clientInfo.appVersion}+${clientInfo.buildNumber}';

  void start() {
    if (!messaging.isConfigured) return;
    _subscriptions
      ..add(
        session.statusStream.listen((status) {
          if (status == SessionStatus.signedIn) {
            unawaited(sync());
          } else {
            _registered = null;
          }
        }),
      )
      ..add(messaging.onTokenRefresh.listen((t) => unawaited(sync(token: t))));
    if (session.status == SessionStatus.signedIn) unawaited(sync());
  }

  /// Registers the current (or the given, freshly rotated) token unless it
  /// is already registered for this session. Calls never overlap.
  Future<void> sync({String? token}) async {
    final previous = _running;
    if (previous != null) await previous;
    final run = _sync(token);
    _running = run;
    try {
      await run;
    } finally {
      if (identical(_running, run)) _running = null;
    }
  }

  Future<void> _sync(String? fresh) async {
    if (!messaging.isConfigured) return;
    if (session.status != SessionStatus.signedIn) return;
    try {
      if (!_permissionAsked) {
        _permissionAsked = true;
        // The answer only decides whether the OS shows pushes; the device
        // is registered either way (data messages, a later opt-in).
        await messaging.requestPermission();
      }
      final token = fresh ?? await messaging.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      if (token == _registered) return;
      await devices.register(
        fcmToken: token,
        platform: clientInfo.platform,
        appVersion: appVersion,
      );
      if (session.status == SessionStatus.signedIn) _registered = token;
    } catch (_) {
      // Best effort: the next sign-in, start or token refresh retries.
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}

/// The push channel. No-op until the Firebase projects exist (D-19); the
/// Firebase adapter replaces it then. Tests override it.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const NoopPushMessaging(),
);

/// `/me/devices/`: the API, or the recorder with `FAKE_API`.
final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => isFakeApi(ref)
      ? FakeDeviceRepository()
      : ApiDeviceRepository(ref.watch(jivoApiProvider)),
);

/// The running [PushRegistrar] (watched by the app root).
final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(
    messaging: ref.watch(pushMessagingProvider),
    devices: ref.watch(deviceRepositoryProvider),
    clientInfo: ref.watch(clientInfoProvider),
    session: ref.watch(sessionProvider),
  )..start();
  ref.onDispose(registrar.dispose);
  return registrar;
});
