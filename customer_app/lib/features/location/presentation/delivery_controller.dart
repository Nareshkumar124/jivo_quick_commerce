import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/delivery_location.dart';

/// The selected delivery location and its serviceability (`03 §2.3`).
@immutable
class DeliveryState {
  const DeliveryState({
    this.location,
    this.serviceability,
    this.checking = false,
    this.error,
    this.storeGeneration = 0,
  });

  /// Null until the customer picks a location.
  final DeliveryLocation? location;

  /// The last check of [location]; kept while re-checking.
  final Serviceability? serviceability;
  final bool checking;

  /// The last check failed (only shown when there is no earlier result).
  final Object? error;

  /// Bumped when the API reports the store gone (`STORE_NOT_FOUND`), so
  /// store-scoped data reloads even if the re-check returns the same id.
  final int storeGeneration;

  /// The store to send as `X-Store-Id`, when the location is serviceable.
  int? get storeId =>
      serviceability?.serviceable ?? false ? serviceability?.store?.id : null;

  StoreInfo? get store => storeId == null ? null : serviceability!.store;
}

/// What happens if the customer switches to a location.
enum LocationOutcome {
  /// Same store, or nothing in the cart: switch.
  ok,

  /// Show the not-serviceable screen.
  notServiceable,

  /// A different store and a non-empty cart: confirm clearing the cart
  /// (stock and prices are per store, `03 §2.3`).
  storeChange,
}

typedef LocationCheck = ({
  LocationOutcome outcome,
  Serviceability serviceability,
});

class DeliveryController extends Notifier<DeliveryState> {
  @override
  DeliveryState build() {
    final saved = ref.read(deliveryLocationStoreProvider).read();
    if (saved == null) return const DeliveryState();
    Future.microtask(refresh);
    return DeliveryState(location: saved, checking: true);
  }

  /// Re-checks the selected location (start-up, pull to refresh, retry).
  Future<void> refresh() async {
    final location = state.location;
    if (location == null) return;
    state = DeliveryState(
      location: location,
      serviceability: state.serviceability,
      checking: true,
      storeGeneration: state.storeGeneration,
    );
    try {
      final result = await ref
          .read(serviceabilityRepositoryProvider)
          .check(location.point);
      if (ref.mounted && state.location == location) {
        state = DeliveryState(
          location: location,
          serviceability: result,
          storeGeneration: state.storeGeneration,
        );
      }
    } catch (error) {
      if (ref.mounted && state.location == location) {
        state = DeliveryState(
          location: location,
          serviceability: state.serviceability,
          error: error,
          storeGeneration: state.storeGeneration,
        );
      }
    }
  }

  /// The API answered `STORE_NOT_FOUND`: forget the store and check the
  /// location again (the store may have been replaced or deactivated).
  Future<void> storeGone() async {
    final location = state.location;
    if (location == null || state.checking) return;
    state = DeliveryState(
      location: location,
      checking: true,
      storeGeneration: state.storeGeneration + 1,
    );
    await refresh();
  }

  /// Checks [location] without selecting it. Throws `ApiError`.
  Future<LocationCheck> check(DeliveryLocation location) async {
    final result = await ref
        .read(serviceabilityRepositoryProvider)
        .check(location.point);
    if (!result.serviceable) {
      return (outcome: LocationOutcome.notServiceable, serviceability: result);
    }
    final currentStore = state.storeId;
    final cartEmpty = ref.read(cartProvider).snapshot.isEmpty;
    final outcome =
        currentStore != null && result.store?.id != currentStore && !cartEmpty
        ? LocationOutcome.storeChange
        : LocationOutcome.ok;
    return (outcome: outcome, serviceability: result);
  }

  /// Selects [location] with its [serviceability] from [check]. With
  /// [clearCart], empties the cart first (store change).
  Future<void> select(
    DeliveryLocation location,
    Serviceability serviceability, {
    bool clearCart = false,
  }) async {
    if (clearCart) await ref.read(cartProvider.notifier).clear();
    state = DeliveryState(
      location: location,
      serviceability: serviceability,
      storeGeneration: state.storeGeneration,
    );
    await ref.read(deliveryLocationStoreProvider).write(location);
  }
}

final deliveryProvider = NotifierProvider<DeliveryController, DeliveryState>(
  DeliveryController.new,
);

/// The serving store's id (`X-Store-Id`), or null.
final currentStoreIdProvider = Provider<int?>(
  (ref) => ref.watch(deliveryProvider.select((s) => s.storeId)),
);

/// What store-scoped data depends on: the store and its generation. Catalog
/// providers watch this, so they reload on a store change and after
/// `STORE_NOT_FOUND`.
final storeScopeProvider = Provider<(int?, int)>(
  (ref) =>
      ref.watch(deliveryProvider.select((s) => (s.storeId, s.storeGeneration))),
);

/// Whether this build can show a map.
final mapsAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(mapsAvailabilityProvider).isAvailable(),
);
