import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../app/router.dart';
import '../../../shared/links/deep_links.dart';
import '../data/push_messaging.dart';
import 'push_registration.dart';

/// Opens the screen for a tapped notification (`03 §2.12`) through
/// [notificationLocation]: order → tracking (or detail), product,
/// collection, category, or a `jivo://` link.
///
/// A tap that arrives before the user is in the app (cold start: splash,
/// login, complete-profile) is kept and opened once they are.
class NotificationTapRouter {
  NotificationTapRouter({
    required this.messaging,
    required this.router,
    required this.session,
    required this.launch,
    required this.trackingAvailable,
  });

  final PushMessaging messaging;
  final GoRouter router;
  final SessionManager session;
  final LaunchState launch;
  final bool Function() trackingAvailable;

  StreamSubscription<Object?>? _taps;
  String? _pending;

  /// The location waiting for the user to be in the app.
  @visibleForTesting
  String? get pending => _pending;

  bool get _inApp =>
      launch.ready &&
      session.status == SessionStatus.signedIn &&
      launch.profileComplete != false;

  void start() {
    if (!messaging.isConfigured) return;
    _taps = messaging.onNotificationTap.listen(handle);
    launch.addListener(_flush);
    session.addListener(_flush);
    unawaited(
      messaging.takeInitialNotification().then((data) {
        if (data != null) handle(data);
      }),
    );
  }

  /// Routes one tapped notification's data payload.
  void handle(Map<String, Object?> data) {
    final location = notificationLocation(
      data,
      trackingAvailable: trackingAvailable(),
    );
    if (location == null) return;
    if (_inApp) {
      unawaited(router.push(location));
    } else if (session.status != SessionStatus.signedOut) {
      // Still starting up (splash, complete-profile): open it once in.
      _pending = location;
    }
    // Signed out: dropped. Held, it would open for whoever signs in next,
    // possibly another user (code review of 2e2560a).
  }

  /// Opens a held tap if the user is in the app now (tests).
  @visibleForTesting
  void flushForTest() => _flush();

  void _flush() {
    final location = _pending;
    if (location == null) return;
    if (session.status == SessionStatus.signedOut) {
      // Dropped: after the next login it could open another user's order.
      _pending = null;
      return;
    }
    if (!_inApp) return;
    _pending = null;
    router.go(Routes.home);
    unawaited(router.push(location));
  }

  void dispose() {
    unawaited(_taps?.cancel());
    launch.removeListener(_flush);
    session.removeListener(_flush);
  }
}

/// The running [NotificationTapRouter] (watched by the app root).
final notificationTapRouterProvider = Provider<NotificationTapRouter>((ref) {
  final tapRouter = NotificationTapRouter(
    messaging: ref.watch(pushMessagingProvider),
    router: ref.watch(routerProvider),
    session: ref.watch(sessionProvider),
    launch: ref.watch(launchStateProvider),
    trackingAvailable: () => ref.read(trackingAvailableProvider),
  )..start();
  ref.onDispose(tapRouter.dispose);
  return tapRouter;
});
