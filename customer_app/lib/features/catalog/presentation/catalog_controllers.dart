import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/catalog_models.dart';

/// Catalog state. Everything is scoped to the serving store: providers watch
/// [storeScopeProvider], so switching store reloads them.

/// Runs a store-scoped call. On `STORE_NOT_FOUND` the saved store is dropped
/// and the location re-checked; the error still reaches the screen.
Future<T> storeScoped<T>(Ref ref, Future<T> Function() call) async {
  final delivery = ref.read(deliveryProvider.notifier);
  try {
    return await call();
  } catch (error) {
    if (ApiError.from(error).code == ApiErrorCode.storeNotFound) {
      // Not during this provider's build: after it.
      Future.microtask(delivery.storeGone);
    }
    rethrow;
  }
}

/// `GET /home/`.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) {
  ref.watch(storeScopeProvider);
  final repository = ref.watch(catalogRepositoryProvider);
  return storeScoped(ref, repository.home);
});

/// `GET /categories/`.
final categoriesProvider = FutureProvider<List<ProductCategory>>((ref) {
  ref.watch(storeScopeProvider);
  final repository = ref.watch(catalogRepositoryProvider);
  return storeScoped(ref, repository.categories);
});

/// `GET /products/{slug}/`.
final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, String>((ref, slug) {
      ref.watch(storeScopeProvider);
      final repository = ref.watch(catalogRepositoryProvider);
      return storeScoped(ref, () => repository.product(slug));
    });

/// Trending searches (`03 §2.7`): the suggestions for a blank query. Per
/// store, so it reloads on a store change.
final trendingSearchesProvider =
    FutureProvider.autoDispose<List<SearchSuggestion>>((ref) {
      ref.watch(storeScopeProvider);
      final repository = ref.watch(catalogRepositoryProvider);
      return storeScoped(ref, () => repository.suggest(''));
    });

/// Finds [slug] in the tree: returns the top-level category and, when [slug]
/// is a sub-category, that child.
({ProductCategory top, ProductCategory? child})? findCategory(
  List<ProductCategory> tree,
  String slug,
) {
  for (final top in tree) {
    if (top.slug == slug) return (top: top, child: null);
    for (final child in top.children) {
      if (child.slug == slug) return (top: top, child: child);
    }
  }
  return null;
}

/// What a paginated product grid shows.
@immutable
sealed class ProductQuery {
  const ProductQuery();
}

/// A category (or sub-category) list with a sort.
class CategoryQuery extends ProductQuery {
  const CategoryQuery(this.slug, [this.sort = ProductSort.relevance]);

  final String slug;
  final ProductSort sort;

  @override
  bool operator ==(Object other) =>
      other is CategoryQuery && other.slug == slug && other.sort == sort;

  @override
  int get hashCode => Object.hash(slug, sort);
}

class CollectionQuery extends ProductQuery {
  const CollectionQuery(this.slug);

  final String slug;

  @override
  bool operator ==(Object other) =>
      other is CollectionQuery && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

class SearchQuery extends ProductQuery {
  const SearchQuery(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is SearchQuery && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

@immutable
class PagedProducts {
  const PagedProducts({
    this.items = const [],
    this.nextPage,
    this.title,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<CatalogProduct> items;
  final int? nextPage;

  /// Collection name (collection pages).
  final String? title;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextPage != null;

  PagedProducts copyWith({
    List<CatalogProduct>? items,
    int? nextPage,
    bool clearNextPage = false,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearError = false,
  }) => PagedProducts(
    items: items ?? this.items,
    nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
    title: title,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
  );
}

/// A product grid with infinite scroll (`03 §2.6`).
class PagedProductsController extends AsyncNotifier<PagedProducts> {
  PagedProductsController(this.query);

  final ProductQuery query;

  Future<ProductPage> _fetch(int page) {
    final repository = ref.read(catalogRepositoryProvider);
    return storeScoped(
      ref,
      () => switch (query) {
        CategoryQuery(:final slug, :final sort) => repository.products(
          category: slug,
          sort: sort,
          page: page,
        ),
        CollectionQuery(:final slug) => repository.collection(slug, page: page),
        SearchQuery(:final text) => repository.search(text, page: page),
      },
    );
  }

  @override
  Future<PagedProducts> build() async {
    ref.watch(storeScopeProvider);
    final first = await _fetch(1);
    return PagedProducts(
      items: first.items,
      nextPage: first.nextPage,
      title: first.title,
    );
  }

  /// Loads the next page, once at a time. A failure is kept in
  /// [PagedProducts.loadMoreError] for a footer retry.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await _fetch(current.nextPage!);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextPage: page.nextPage,
          clearNextPage: page.nextPage == null,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error),
      );
    }
  }
}

final pagedProductsProvider = AsyncNotifierProvider.autoDispose
    .family<PagedProductsController, PagedProducts, ProductQuery>(
      PagedProductsController.new,
    );
