import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/addresses/presentation/address_screens.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/launch/presentation/app_control_screens.dart';
import '../features/launch/presentation/onboarding_screen.dart';
import '../features/launch/presentation/splash_screen.dart';
import '../features/profile/presentation/account_screens.dart';
import 'launch_state.dart';
import 'providers.dart';
import 'redirect.dart';

/// App routes. Each has a `name` (reported as the analytics screen view).
/// Redirects follow the session, app-control and launch state; see
/// [resolveRedirect].
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  final signals = ref.watch(appControlProvider);
  final launch = ref.watch(launchStateProvider);

  GoRoute route(
    String path,
    String name,
    Widget Function(GoRouterState state) build,
  ) => GoRoute(
    path: path,
    name: name,
    builder: (context, state) => build(state),
  );

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: Listenable.merge([session, signals, launch]),
    observers: [AnalyticsNavigatorObserver(ref.watch(analyticsProvider))],
    redirect: (context, state) => resolveRedirect(
      location: state.matchedLocation,
      control: signals.current,
      session: session.status,
      ready: launch.ready,
      onboardingSeen: launch.onboardingSeen,
      profileComplete: launch.profileComplete,
      hasOtpChallenge: ref.read(authFlowProvider).challenge != null,
    ),
    routes: [
      route(Routes.splash, 'splash', (_) => const SplashScreen()),
      route(Routes.onboarding, 'onboarding', (_) => const OnboardingScreen()),
      route(
        Routes.updateRequired,
        'update_required',
        (_) => const ForceUpdateScreen(),
      ),
      route(
        Routes.maintenance,
        'maintenance',
        (_) => const MaintenanceScreen(),
      ),
      route(Routes.login, 'login', (_) => const LoginScreen()),
      route(Routes.otp, 'otp', (_) => const OtpScreen()),
      route(
        Routes.completeProfile,
        'complete_profile',
        (_) => const CompleteProfileScreen(),
      ),
      route(Routes.home, 'home', (_) => const HomeScreen()),
      route(Routes.account, 'account', (_) => const AccountScreen()),
      route(
        Routes.editProfile,
        'edit_profile',
        (_) => const EditProfileScreen(),
      ),
      route(Routes.addresses, 'addresses', (_) => const AddressListScreen()),
      route(Routes.newAddress, 'address_new', (_) => const AddressFormScreen()),
      route(
        '${Routes.addresses}/:id',
        'address_edit',
        (state) => AddressFormScreen(
          addressId: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
      route(
        Routes.deleteAccount,
        'delete_account',
        (_) => const DeleteAccountScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
