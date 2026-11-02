import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/addresses/data/device_location.dart';
import '../features/addresses/presentation/address_screens.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/catalog/presentation/categories_screen.dart';
import '../features/catalog/presentation/collection_screen.dart';
import '../features/catalog/presentation/product_detail_screen.dart';
import '../features/catalog/presentation/product_list_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/launch/presentation/app_control_screens.dart';
import '../features/launch/presentation/onboarding_screen.dart';
import '../features/launch/presentation/splash_screen.dart';
import '../features/location/presentation/location_flow.dart';
import '../features/location/presentation/location_screen.dart';
import '../features/location/presentation/map_picker_screen.dart';
import '../features/location/presentation/not_serviceable_screen.dart';
import '../features/orders/presentation/order_again_screen.dart';
import '../features/profile/presentation/account_screens.dart';
import '../features/search/presentation/search_screen.dart';
import 'app_shell.dart';
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

  final analytics = ref.watch(analyticsProvider);
  StatefulShellBranch tab(String path, String name, Widget screen) =>
      StatefulShellBranch(
        observers: [AnalyticsNavigatorObserver(analytics)],
        routes: [route(path, name, (_) => screen)],
      );

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: Listenable.merge([session, signals, launch]),
    observers: [AnalyticsNavigatorObserver(analytics)],
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
      // The bottom tabs (`03 §1`). Other screens are pushed over them.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          tab(Routes.home, 'home', const HomeScreen()),
          tab(Routes.categories, 'categories', const CategoriesScreen()),
          tab(Routes.orderAgain, 'order_again', const OrderAgainScreen()),
          tab(Routes.account, 'account', const AccountScreen()),
        ],
      ),
      route(
        '/category/:slug',
        'product_list',
        (state) => ProductListScreen(
          slug: state.pathParameters['slug']!,
          sub: state.uri.queryParameters['sub'],
        ),
      ),
      route(
        '/product/:slug',
        'product_detail',
        (state) => ProductDetailScreen(slug: state.pathParameters['slug']!),
      ),
      route(
        '/collection/:slug',
        'collection',
        (state) => CollectionScreen(slug: state.pathParameters['slug']!),
      ),
      route(Routes.search, 'search', (_) => const SearchScreen()),
      route(Routes.location, 'location', (_) => const LocationScreen()),
      route(
        Routes.mapPicker,
        'map_picker',
        (state) => MapPickerScreen(initial: state.extra as GeoPoint?),
      ),
      route(
        Routes.notServiceable,
        'not_serviceable',
        (state) =>
            NotServiceableScreen(args: state.extra as NotServiceableArgs?),
      ),
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
