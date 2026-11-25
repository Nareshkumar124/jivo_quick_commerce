import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/repositories.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/reward.dart';

/// The signed-in customer's rewards (`GET /account/rewards/`). Loaded each
/// time the Rewards screen opens (auto-dispose), so a reward used, claimed
/// or earned since shows its new state. Nobody signed in: `AUTH_REQUIRED`
/// without a request.
final rewardsProvider = FutureProvider.autoDispose<RewardsSummary>((ref) {
  if (ref.watch(signedInUserIdProvider) == null) {
    throw const ApiError(code: ApiErrorCode.authRequired);
  }
  return ref.watch(rewardsRepositoryProvider).fetch();
});

/// The catalog category whose sizes a free carton can be (ADR 0002: the
/// water sizes sold at the store). One place to change if the store's
/// water category gets another slug.
const freeCartonCategorySlug = 'water';

/// A size the customer can pick for a free carton.
@immutable
class FreeSizeOption {
  const FreeSizeOption({required this.productName, required this.variant});

  final String productName;

  /// The store's variant (price, stock and image as the catalog sends
  /// them); its id is the `free_variant_id`.
  final CatalogVariant variant;
}

/// The water sizes sold and in stock at the current store, from the same
/// catalog list the Water category page loads (`GET /products/?category=`,
/// first page; the store sells three sizes). Store-scoped: a store change
/// reloads it.
final freeCartonSizesProvider =
    FutureProvider.autoDispose<List<FreeSizeOption>>((ref) {
      ref.watch(storeScopeProvider);
      final repository = ref.watch(catalogRepositoryProvider);
      return storeScoped(ref, () async {
        final page = await repository.products(
          category: freeCartonCategorySlug,
        );
        return freeSizeOptions(page.items);
      });
    });

/// Every in-stock variant of [products], in the catalog's order, each size
/// once.
List<FreeSizeOption> freeSizeOptions(List<CatalogProduct> products) {
  final seen = <int>{};
  return [
    for (final product in products)
      for (final variant in product.variants)
        if (variant.inStock && seen.add(variant.id))
          FreeSizeOption(productName: product.name, variant: variant),
  ];
}
