import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/auth/presentation/login_controllers.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/phone_login_screen.dart';
import '../features/auth/presentation/rider_account_controller.dart';
import '../features/launch/presentation/launch_controller.dart';
import '../features/launch/presentation/maintenance_screen.dart';
import '../features/launch/presentation/splash_screen.dart';
import '../features/launch/presentation/update_screen.dart';
import '../features/location/presentation/location_debug_screen.dart';
import '../features/offers/presentation/offer_alert_preview_screen.dart';
import '../features/onboarding/presentation/register_placeholder_screen.dart';
import '../features/onboarding/presentation/rider_status_screen.dart';
import '../features/permissions/presentation/location_disclosure_screen.dart';
import '../features/permissions/presentation/permissions_gate_screen.dart';
import '../features/shift/presentation/home_screen.dart';
import 'env.dart';
import 'providers.dart';
import 'route_guard.dart';
import 'routes.dart';

/// Where the router starts. Overridden in `bootstrap()` when the app was
/// launched by an offer alert (dev flavor).
final initialLocationProvider = Provider<String>((ref) => Routes.splash);

/// The router. Built once: session, app-control, launch, account and OTP
/// changes only re-run [riderRedirect] (through `refreshListenable`), so the
/// navigation stack survives login and status changes.
final routerProvider = Provider<GoRouter>((ref) {
  final env = ref.read(appEnvProvider);
  final session = ref.read(sessionManagerProvider);
  final signals = ref.read(appControlSignalsProvider);

  // Rider-side state that also affects routing.
  final local = ValueNotifier<int>(0);
  void bump() => local.value++;
  ref.listen(
    launchControllerProvider.select(
      (s) => (s.config != null, s.softUpdatePending),
    ),
    (_, _) => bump(),
  );
  ref.listen(riderAccountControllerProvider, (_, _) => bump());
  ref.listen(otpChallengeProvider, (_, _) => bump());

  final router = GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: Listenable.merge([session, signals, local]),
    observers: [AnalyticsNavigatorObserver(ref.read(analyticsProvider))],
    redirect: (context, state) {
      final launch = ref.read(launchControllerProvider);
      return riderRedirect(
        location: state.matchedLocation,
        appControl: signals.current,
        configLoaded: launch.config != null,
        softUpdatePending: launch.softUpdatePending,
        sessionStatus: session.status,
        account: ref.read(riderAccountControllerProvider),
        hasOtpChallenge: ref.read(otpChallengeProvider) != null,
        showDevTools: env.showDevTools,
      );
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.update,
        name: 'update',
        builder: (_, _) => const UpdateScreen(),
      ),
      GoRoute(
        path: Routes.maintenance,
        name: 'maintenance',
        builder: (_, _) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (_, _) => const PhoneLoginScreen(),
        routes: [
          // A sub-route opened with `go`, so the guard sees `/login/otp` as
          // the matched location (a pushed top-level route would not be).
          GoRoute(
            path: 'otp',
            name: 'otp',
            builder: (_, _) => const OtpScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.register,
        name: 'register_placeholder',
        builder: (_, _) => const RegisterPlaceholderScreen(),
      ),
      GoRoute(
        path: Routes.riderStatus,
        name: 'rider_status',
        builder: (_, _) => const RiderStatusScreen(),
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (_, _) => const HomeScreen(),
      ),
      // The Phase 0 spike screens exist in the dev flavor only.
      if (env.showDevTools) ...[
        GoRoute(
          path: Routes.permissions,
          builder: (_, _) => const PermissionsGateScreen(),
          routes: [
            GoRoute(
              path: 'disclosure',
              builder: (_, _) => const LocationDisclosureScreen(),
            ),
          ],
        ),
        GoRoute(
          path: Routes.locationDebug,
          builder: (_, _) => const LocationDebugScreen(),
        ),
        GoRoute(
          path: Routes.offerPreview,
          builder: (_, _) => const OfferAlertPreviewScreen(),
        ),
      ],
    ],
  );
  ref.onDispose(() {
    router.dispose();
    local.dispose();
  });
  return router;
});
