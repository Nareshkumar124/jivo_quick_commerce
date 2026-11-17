import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../../shared/storage/app_flags.dart';
import '../data/device_repository.dart';
import '../data/push_messaging.dart';

/// When the app asks for notification permission (`03 §2.12`): never on
/// cold start, only in context.
enum PushPermissionMoment {
  /// Right after the user signs in.
  signIn,

  /// On the order-placed screen of the first order (a second, in-context
  /// chance if the user declined at sign-in).
  firstOrder,
}

/// Asks for notification permission (Android 13+ `POST_NOTIFICATIONS`,
/// iOS) at most once per [PushPermissionMoment] on this install. Android
/// itself stops showing the dialog after two refusals, so two moments are
/// the most that can be useful.
class PushPermissionPrompt {
  PushPermissionPrompt({required this.messaging, required this.flags});

  final PushMessaging messaging;
  final AppFlags flags;

  /// Asks unless push is off or this [moment] already asked. Returns the
  /// answer, or null when nothing was asked. Never throws.
  Future<bool?> maybeAsk(PushPermissionMoment moment) async {
    if (!messaging.isConfigured) return null;
    try {
      if (flags.pushPermissionAsked(moment.name)) return null;
      await flags.markPushPermissionAsked(moment.name);
      return await messaging.requestPermission();
    } catch (_) {
      return null;
    }
  }
}

/// Keeps this device's push token registered with the server
/// (`POST /me/devices/`): on sign-in, on every app start while signed in
/// (which also covers an app-version change) and on every token refresh.
/// After sign-out it deletes the local token, so pushes for the
/// signed-out user stop even when the logout call didn't reach the server
/// (an expired session); the next sign-in registers a new token.
///
/// On sign-in it first asks for notification permission through [prompt]
/// (once per install); an app start while already signed in never asks.
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
    this.prompt,
  });

  final PushMessaging messaging;
  final DeviceRepository devices;
  final ClientInfo clientInfo;
  final SessionManager session;
  final PushPermissionPrompt? prompt;

  final List<StreamSubscription<Object?>> _subscriptions = [];
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
            unawaited(_afterSignIn());
          } else if (status == SessionStatus.signedOut) {
            unawaited(_afterSignOut());
          }
        }),
      )
      ..add(messaging.onTokenRefresh.listen((t) => unawaited(sync(token: t))));
    if (session.status == SessionStatus.signedIn) unawaited(sync());
  }

  Future<void> _afterSignIn() async {
    // The answer only decides whether the OS shows pushes; the device is
    // registered either way (a later opt-in in system settings works).
    await prompt?.maybeAsk(PushPermissionMoment.signIn);
    await sync();
  }

  Future<void> _afterSignOut() => _serialized(() async {
    _registered = null;
    _token = null;
    await messaging.deleteToken();
  });

  /// Registers the current (or the given, freshly rotated) token unless it
  /// is already registered for this session. Calls never overlap.
  Future<void> sync({String? token}) => _serialized(() => _sync(token));

  /// Runs [action] after the running one; registrations and the sign-out
  /// token delete never overlap.
  Future<void> _serialized(Future<void> Function() action) async {
    final previous = _running;
    if (previous != null) await previous;
    final run = action();
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

/// The push channel: set at start-up from `initializePush()` (Firebase when
/// the flavor has its config, else no-op). Tests override it.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const NoopPushMessaging(),
);

/// Asks for notification permission at the right moments.
final pushPermissionPromptProvider = Provider<PushPermissionPrompt>(
  (ref) => PushPermissionPrompt(
    messaging: ref.watch(pushMessagingProvider),
    flags: ref.watch(appFlagsProvider),
  ),
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
    prompt: ref.watch(pushPermissionPromptProvider),
  )..start();
  ref.onDispose(registrar.dispose);
  return registrar;
});
