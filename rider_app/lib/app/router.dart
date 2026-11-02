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
import '../features/offers/presentation/offer_controller.dart';
import '../features/offers/presentation/offer_screen.dart';
import '../features/onboarding/domain/image_picking.dart';
import '../features/onboarding/domain/kyc_document.dart';
import '../features/onboarding/presentation/bank_details_screen.dart';
import '../features/onboarding/presentation/document_capture_screen.dart';
import '../features/onboarding/presentation/documents_screen.dart';
import '../features/onboarding/presentation/onboarding_providers.dart';
import '../features/onboarding/presentation/onboarding_status_screen.dart';
import '../features/onboarding/presentation/register_placeholder_screen.dart';
import '../features/onboarding/presentation/registration_screen.dart';
import '../features/onboarding/presentation/rider_status_screen.dart';
import '../features/permissions/presentation/location_disclosure_screen.dart';
import '../features/permissions/presentation/permissions_gate_screen.dart';
import '../features/shift/presentation/home_screen.dart';
import '../features/task/presentation/failed_delivery_screen.dart';
import '../features/task/presentation/pickup_scan_screen.dart';
import '../features/task/presentation/task_flow_controller.dart';
import '../features/task/presentation/task_screen.dart';
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
  final onboarding = ref.read(riderOnboardingEnabledProvider);

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
  ref.listen(
    taskFlowControllerProvider.select((s) => s.hasTask),
    (_, _) => bump(),
  );
  ref.listen(offerControllerProvider.select((s) => s.isOpen), (_, _) => bump());

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
        hasRiderTask: ref.read(taskFlowControllerProvider).hasTask,
        hasOffer: ref.read(offerControllerProvider).isOpen,
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
      // Registration and KYC (04 §2.2) run against the fake until the rider
      // API lands; builds without it keep the Phase 1 placeholders.
      GoRoute(
        path: Routes.register,
        name: 'register',
        builder: (_, _) => onboarding
            ? const RegistrationScreen()
            : const RegisterPlaceholderScreen(),
      ),
      GoRoute(
        path: Routes.riderStatus,
        name: 'rider_status',
        builder: (_, _) => onboarding
            ? const OnboardingStatusScreen()
            : const RiderStatusScreen(),
        routes: [
          if (onboarding) ...[
            GoRoute(
              path: 'documents',
              name: 'documents',
              builder: (_, _) => const DocumentsScreen(),
              routes: [
                GoRoute(
                  path: ':type',
                  name: 'document_capture',
                  redirect: (_, state) =>
                      _documentType(state) == null ? Routes.documents : null,
                  builder: (_, state) => DocumentCaptureScreen(
                    type: _documentType(state)!,
                    recovered: state.extra is PickedImage
                        ? state.extra! as PickedImage
                        : null,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'bank',
              name: 'bank_details',
              builder: (_, _) => const BankDetailsScreen(),
            ),
          ],
        ],
      ),
      GoRoute(
        path: Routes.home,
        name: 'home',
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.offer,
        name: 'offer',
        builder: (_, _) => const OfferScreen(),
      ),
      GoRoute(
        path: Routes.task,
        name: 'task',
        builder: (_, _) => const TaskScreen(),
        routes: [
          GoRoute(
            path: 'scan',
            name: 'task_scan',
            builder: (_, _) => const PickupScanScreen(),
          ),
          GoRoute(
            path: 'fail',
            name: 'task_fail',
            builder: (_, _) => const FailedDeliveryScreen(),
          ),
        ],
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

/// The document type of `/rider-status/documents/:type`, or null.
KycDocumentType? _documentType(GoRouterState state) =>
    KycDocumentType.fromWire(state.pathParameters['type']?.toUpperCase());
