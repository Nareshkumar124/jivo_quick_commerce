import '../domain/catalog_models.dart';

/// Catalog reads for the selected store (`06 §2.4`). Every call is scoped by
/// the `X-Store-Id` header the API client adds. Implementations throw
/// `ApiError`; a 404 `STORE_NOT_FOUND` means the saved store is gone (drop
/// it and check serviceability again).
///
/// TODO(api): add `ApiCatalogRepository` on the generated client when the
/// Phase 2 contract lands. Until then the app uses [FakeCatalogRepository].
abstract interface class CatalogRepository {
  /// `GET /home/`.
  Future<HomeFeed> home();

  /// `GET /categories/`: the category tree.
  Future<List<ProductCategory>> categories();

  /// `GET /products/?category=&collection=&sort=&page=`.
  Future<ProductPage> products({
    String? category,
    String? collection,
    ProductSort sort = ProductSort.relevance,
    int page = 1,
  });

  /// `GET /products/{id_or_slug}/`.
  Future<ProductDetail> product(String idOrSlug);

  /// A collection's products; the first page carries the
  /// [ProductPage.title]. `GET /collections/{slug}/` returns the name and up
  /// to 100 products in one page (paging and sorting would use
  /// `GET /products/?collection=`).
  Future<ProductPage> collection(String slug, {int page = 1});

  /// `GET /search/?q=`.
  Future<ProductPage> search(String query, {int page = 1});

  /// `GET /search/suggest/?q=`. A blank [query] returns the trending
  /// searches (`03 §2.7`) as keywords.
  Future<List<SearchSuggestion>> suggest(String query);
}
