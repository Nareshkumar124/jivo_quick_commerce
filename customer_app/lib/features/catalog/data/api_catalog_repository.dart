import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../../location/domain/delivery_location.dart';
import '../domain/catalog_models.dart';
import 'catalog_repository.dart';

/// The catalog on the generated client (`06 §2.4`). Every call carries the
/// serving store as `X-Store-Id`; [storeId] reads it at call time.
class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api, this._storeId);

  final api.JivoApi _api;
  final int? Function() _storeId;

  static const pageSize = 20;

  api.CatalogApi get _catalog => _api.getCatalogApi();

  /// The store to query. Without one the catalog can't be read: treat it
  /// like a store that is gone, so the location is checked again.
  int get _store =>
      _storeId() ??
      (throw const ApiError(code: ApiErrorCode.storeNotFound, statusCode: 404));

  @override
  Future<HomeFeed> home() => _guard(() async {
    final feed = (await _catalog.homeRetrieve(xStoreId: _store)).data!;
    return HomeFeed(
      store: storeFromApi(feed.store),
      banners: [for (final b in feed.banners) _banner(b)],
      categories: [for (final c in feed.categories) _tile(c)],
      collections: [
        for (final c in feed.collections)
          HomeCollection(
            slug: c.slug,
            name: c.name,
            items: [for (final p in c.products) _card(p)],
            hasMore: c.hasMore,
          ),
      ],
      buyAgain: [for (final p in feed.buyAgain) _card(p)],
    );
  });

  @override
  Future<List<ProductCategory>> categories() => _guard(() async {
    final tree = (await _catalog.categoriesList(xStoreId: _store)).data!;
    return [
      for (final node in tree.results)
        ProductCategory(
          id: node.id,
          slug: node.slug,
          name: node.name,
          imageUrl: node.image?.medium,
          children: [for (final c in node.children) _tile(c)],
        ),
    ];
  });

  @override
  Future<ProductPage> products({
    String? category,
    String? collection,
    ProductSort sort = ProductSort.relevance,
    int page = 1,
  }) => _guard(() async {
    final result = (await _catalog.productsList(
      xStoreId: _store,
      category: category,
      collection: collection,
      sort: sort.apiValue,
      page: page,
      pageSize: pageSize,
    )).data!;
    return _page(result, page);
  });

  @override
  Future<ProductDetail> product(String idOrSlug) => _guard(() async {
    final p = (await _catalog.productsRetrieve(
      xStoreId: _store,
      idOrSlug: idOrSlug,
    )).data!;
    return ProductDetail(
      id: p.id,
      slug: p.slug,
      name: p.name,
      brand: p.brand,
      isVeg: p.isVeg,
      category: _tile(p.category),
      shortDescription: p.shortDescription,
      description: p.description,
      highlights: p.highlights,
      defaultVariantId: p.defaultVariantId,
      variants: [for (final v in p.variants) _variantDetail(v)],
      label: ProductLabel(
        ingredients: p.ingredients,
        nutrition: p.nutrition == null
            ? null
            : NutritionTable(
                columns: p.nutrition!.columns,
                rows: [
                  for (final r in p.nutrition!.rows)
                    NutritionRow(
                      name: r.name,
                      values: r.values,
                      isSubRow: r.isSubRow,
                    ),
                ],
              ),
        shelfLife: p.shelfLife,
        storageInstructions: p.storageInstructions,
        countryOfOrigin: p.countryOfOrigin,
        manufacturer: p.manufacturer,
        marketer: p.marketer,
        importer: p.importer,
        consumerCare: p.consumerCare,
        fssaiLicenseNo: p.fssaiLicenseNo,
      ),
      similar: [for (final s in p.similarProducts) _card(s)],
    );
  });

  /// `GET /collections/{slug}/` returns the name and up to 100 products in
  /// one page; there is no second page.
  @override
  Future<ProductPage> collection(String slug, {int page = 1}) =>
      _guard(() async {
        final c = (await _catalog.collectionsRetrieve(
          xStoreId: _store,
          slug: slug,
        )).data!;
        return ProductPage(
          items: page == 1 ? [for (final p in c.products) _card(p)] : const [],
          title: c.name,
        );
      });

  @override
  Future<ProductPage> search(String query, {int page = 1}) => _guard(() async {
    final result = (await _catalog.searchProducts(
      xStoreId: _store,
      q: query,
      page: page,
      pageSize: pageSize,
    )).data!;
    return _page(result, page);
  });

  @override
  Future<List<SearchSuggestion>> suggest(String query) => _guard(() async {
    final result = (await _catalog.searchSuggest(
      xStoreId: _store,
      q: query,
    )).data!;
    return [
      for (final s in result.suggestions)
        SearchSuggestion(
          type: switch (s.type) {
            api.SearchSuggestionTypeEnum.product => SuggestionType.product,
            api.SearchSuggestionTypeEnum.category => SuggestionType.category,
            _ => SuggestionType.keyword,
          },
          text: s.text,
          query: s.query,
          slug: s.slug,
          imageUrl: s.image?.thumbnail,
        ),
    ];
  });

  ProductPage _page(api.PaginatedProductCardList result, int page) =>
      ProductPage(
        items: [for (final p in result.results) _card(p)],
        nextPage: result.next == null ? null : page + 1,
      );
}

/// `StoreStatus` as the app's [StoreInfo].
StoreInfo storeFromApi(api.StoreStatus s) =>
    StoreInfo(id: s.id, name: s.name, isOpen: s.isOpen, opensAt: s.opensAt);

ProductCategory _tile(api.CategoryTile c) => ProductCategory(
  id: c.id,
  slug: c.slug,
  name: c.name,
  imageUrl: c.image?.medium,
);

HomeBanner _banner(api.HomeBanner b) {
  final value = b.linkValue.trim();
  final BannerLink link = switch (b.linkType) {
    api.BannerLinkTypeEnum.category when value.isNotEmpty => CategoryBannerLink(
      value,
    ),
    api.BannerLinkTypeEnum.collection when value.isNotEmpty =>
      CollectionBannerLink(value),
    api.BannerLinkTypeEnum.product when value.isNotEmpty => ProductBannerLink(
      value,
    ),
    api.BannerLinkTypeEnum.url => switch (Uri.tryParse(value)) {
      final Uri uri when uri.scheme == 'https' => UrlBannerLink(uri),
      _ => const NoBannerLink(),
    },
    _ => const NoBannerLink(),
  };
  return HomeBanner(
    id: b.id,
    title: b.title,
    imageUrl: b.image.large,
    link: link,
  );
}

StockStatus _stock(api.StockStatusEnum s) => switch (s) {
  api.StockStatusEnum.IN_STOCK => StockStatus.inStock,
  api.StockStatusEnum.LOW_STOCK => StockStatus.lowStock,
  // Unknown values are treated as not sellable.
  _ => StockStatus.outOfStock,
};

UnitPrice? _unitPrice(api.UnitPrice? u) =>
    u == null ? null : (amount: u.amount, per: u.per);

CatalogVariant _variant(api.VariantSummary v) => CatalogVariant(
  id: v.id,
  name: v.name,
  sellingPrice: v.sellingPrice,
  mrp: v.mrp,
  discountAmount: v.discountAmount,
  discountPercent: v.discountPercent,
  stockStatus: _stock(v.stockStatus),
  orderableQuantity: v.orderableQuantity,
  unitsLeft: v.unitsLeft,
  maxQtyPerOrder: v.maxQtyPerOrder,
  unitPrice: _unitPrice(v.unitPrice),
  imageUrl: v.image?.medium,
);

CatalogVariant _variantDetail(api.VariantDetail v) => CatalogVariant(
  id: v.id,
  name: v.name,
  sellingPrice: v.sellingPrice,
  mrp: v.mrp,
  discountAmount: v.discountAmount,
  discountPercent: v.discountPercent,
  stockStatus: _stock(v.stockStatus),
  orderableQuantity: v.orderableQuantity,
  unitsLeft: v.unitsLeft,
  maxQtyPerOrder: v.maxQtyPerOrder,
  unitPrice: _unitPrice(v.unitPrice),
  imageUrl: v.image?.medium,
  images: [for (final i in v.images) i.large],
  netQuantity: v.netQuantity,
);

CatalogProduct _card(api.ProductCard p) => CatalogProduct(
  id: p.id,
  slug: p.slug,
  name: p.name,
  brand: p.brand,
  isVeg: p.isVeg,
  imageUrl: p.image?.medium,
  defaultVariantId: p.defaultVariantId,
  variants: [for (final v in p.variants) _variant(v)],
);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
