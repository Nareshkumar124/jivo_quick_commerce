import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/addresses/presentation/address_controllers.dart';
import '../features/auth/presentation/auth_flow.dart';
import '../features/cart/presentation/cart_controller.dart';
import '../features/catalog/presentation/catalog_controllers.dart';
import '../features/checkout/presentation/checkout_controller.dart';
import '../features/location/presentation/delivery_controller.dart';
import '../features/notifications/presentation/notification_tap_router.dart';
import '../features/notifications/presentation/push_registration.dart';
import '../features/orders/presentation/active_order_card.dart';
import '../features/orders/presentation/pending_payment.dart';
import '../features/profile/presentation/profile_controllers.dart';
import '../features/search/presentation/search_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/connectivity/connectivity.dart';
import '../shared/widgets/offline_banner.dart';
import 'launch_state.dart';
import 'providers.dart';
import 'repositories.dart';
import 'router.dart';

/// Clears user data when the session ends (logout, deletion, expiry).
final signOutCleanupProvider = Provider<void>((ref) {
  final remove = ref.watch(sessionProvider).addSignOutHook((_) async {
    ref.invalidate(currentUserProvider);
    ref.invalidate(addressListProvider);
    ref.invalidate(authFlowProvider);
    // The cart and any unknown-outcome Idempotency-Key belong to the user
    // who signed out (the dev fake backend plays a per-user server).
    ref.invalidate(fakeCommerceBackendProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(checkoutProvider);
    ref.invalidate(pendingPaymentProvider);
    ref.invalidate(activeOrdersProvider);
    // Local data that belongs to the user (`03 §2.2`): the delivery
    // location (a saved address's id and street; the next user's cart would
    // be refused for it), "Previously bought" in the cached home feed, and
    // the recent searches.
    // A failed prefs write must never keep the signed-out user's session.
    try {
      await ref.read(deliveryProvider.notifier).clearForSignOut();
      ref.invalidate(homeFeedProvider);
      await ref.read(recentSearchesProvider.notifier).clear();
    } finally {
      ref.read(launchStateProvider).clearUser();
    }
  });
  ref.onDispose(remove);
});

/// When the connection comes back (CA-02): re-check what failed while it
/// was gone, outside any screen's error state: the delivery location's
/// serviceability, a cart that didn't load, and a pending payment.
final reconnectRetryProvider = Provider<void>((ref) {
  ref.listen(reconnectProvider, (previous, next) {
    if (previous == next) return;
    if (ref.read(deliveryProvider).error != null) {
      ref.read(deliveryProvider.notifier).refresh();
    }
    if (ref.exists(cartProvider) &&
        ref.read(cartProvider).load == CartLoad.failed) {
      ref.read(cartProvider.notifier).refresh();
    }
    if (ref.read(sessionProvider).isSignedIn) {
      ref.read(pendingPaymentProvider.notifier).check();
    }
  });
});

/// The customer app: theme, `en_IN` localisation, the router and the global
/// offline banner.
class JivoCustomerApp extends ConsumerWidget {
  const JivoCustomerApp({super.key});

  /// English (India): ₹ and Indian digit grouping, IST dates (`09 §6`).
  static const locale = Locale('en', 'IN');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..watch(signOutCleanupProvider)
      ..watch(cartStoreSyncProvider)
      ..watch(reconnectRetryProvider)
      ..watch(pushRegistrarProvider)
      ..watch(notificationTapRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: JivoTheme.light(),
      locale: locale,
      supportedLocales: const [locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        JivoCoreLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox()),
    );
  }
}
