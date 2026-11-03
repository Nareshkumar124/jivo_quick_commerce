import 'package:jivo_core/jivo_core.dart';

import '../../location/domain/delivery_location.dart';
import '../domain/catalog_models.dart';
import 'catalog_repository.dart';

/// A placeholder catalog: a test double and the dev flavor's `FAKE_API=true`
/// stand-in (staging and prod always use `ApiCatalogRepository`). It stands
/// in for the server: prices, discounts, savings and orderable quantities
/// below are server-style values, never computed by the app's own code.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.latency = const Duration(milliseconds: 300),
    this.pageSize = 6,
  });

  /// Simulated network delay. Tests use [Duration.zero].
  final Duration latency;
  final int pageSize;

  /// When set, the next call throws it once (error states in tests).
  Object? failNext;

  /// The store status `GET /home/` reports.
  StoreInfo store = const StoreInfo(
    id: 1,
    name: 'Jivo Connaught Place',
    isOpen: true,
  );

  /// Every call, e.g. `suggest:oli`, for tests.
  final List<String> calls = [];

  Future<T> _respond<T>(String call, T Function() body) async {
    calls.add(call);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return body();
  }

  @override
  Future<HomeFeed> home() => _respond(
    'home',
    () => HomeFeed(
      store: store,
      banners: _banners,
      categories: [
        for (final c in _categories)
          ProductCategory(id: c.id, slug: c.slug, name: c.name),
      ],
      collections: [
        for (final slug in ['bestsellers', 'offers', 'new-launches'])
          HomeCollection(
            slug: slug,
            name: _collectionNames[slug]!,
            items: _collectionItems(slug).take(4).toList(),
            hasMore: _collectionItems(slug).length > 4,
          ),
      ],
      buyAgain: [_card(_products[0]), _card(_products[8])],
    ),
  );

  @override
  Future<List<ProductCategory>> categories() =>
      _respond('categories', () => _categories);

  @override
  Future<ProductPage> products({
    String? category,
    String? collection,
    ProductSort sort = ProductSort.relevance,
    int page = 1,
  }) => _respond('products:${category ?? collection}:${sort.name}:$page', () {
    final List<CatalogProduct> items;
    if (collection != null) {
      items = _collectionItems(collection);
    } else {
      final slugs = _categorySlugs(category);
      items = [
        for (final p in _products)
          if (category == null || slugs.contains(p.category)) _card(p),
      ];
    }
    return _page(_sorted(items, sort), page);
  });

  @override
  Future<ProductDetail> product(String idOrSlug) => _respond(
    'product:$idOrSlug',
    () {
      final match = _products.where(
        (p) => p.slug == idOrSlug || '${p.id}' == idOrSlug,
      );
      if (match.isEmpty) {
        throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
      }
      final p = match.first;
      final card = _card(p);
      return ProductDetail(
        id: p.id,
        slug: p.slug,
        name: p.name,
        defaultVariantId: card.defaultVariantId,
        variants: [for (final v in p.variants) _variant(v, detail: true)],
        shortDescription: 'Placeholder until the catalog API is connected.',
        description:
            '${p.name} from Jivo Wellness.\n\n'
            'Placeholder description until the catalog API is connected.',
        highlights: const [
          'Cold pressed and filtered',
          'No added preservatives',
          'Packed fresh at source',
        ],
        label: const ProductLabel(
          ingredients: 'Refined edible vegetable oil (placeholder)',
          nutrition: NutritionTable(
            columns: ['Per 100 ml', 'Per serving (15 ml)'],
            rows: [
              NutritionRow(name: 'Energy (kcal)', values: ['900', '135']),
              NutritionRow(name: 'Total fat (g)', values: ['100', '15']),
              NutritionRow(
                name: 'Saturated fat (g)',
                values: ['7', '1'],
                isSubRow: true,
              ),
            ],
          ),
          shelfLife: '12 months from manufacture',
          storageInstructions: 'Store in a cool, dry place away from sunlight',
          countryOfOrigin: 'India',
          manufacturer: 'Jivo Wellness Pvt. Ltd. (placeholder)',
          consumerCare: 'care@jivo.in (placeholder)',
          fssaiLicenseNo: '00000000000000',
        ),
        similar: [
          for (final other in _products)
            if (other.category == p.category && other.id != p.id) _card(other),
        ],
      );
    },
  );

  @override
  Future<ProductPage> collection(String slug, {int page = 1}) =>
      _respond('collection:$slug:$page', () {
        final name = _collectionNames[slug];
        if (name == null) {
          throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
        }
        final result = _page(_collectionItems(slug), page);
        return ProductPage(
          items: result.items,
          nextPage: result.nextPage,
          title: name,
        );
      });

  @override
  Future<ProductPage> search(String query, {int page = 1}) =>
      _respond('search:$query:$page', () {
        final q = query.trim().toLowerCase();
        return _page([
          for (final p in _products)
            if (_matches(p, q)) _card(p),
        ], page);
      });

  @override
  Future<List<SearchSuggestion>> suggest(String query) =>
      _respond('suggest:$query', () {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) {
          return [
            for (final text in _trending)
              SearchSuggestion(
                type: SuggestionType.keyword,
                text: text,
                query: text,
              ),
          ];
        }
        return [
          for (final c in _categories)
            if (c.name.toLowerCase().contains(q))
              SearchSuggestion(
                type: SuggestionType.category,
                text: c.name,
                query: c.name,
                slug: c.slug,
              ),
          for (final p in _products.where((p) => _matches(p, q)).take(6))
            SearchSuggestion(
              type: SuggestionType.product,
              text: p.name,
              query: p.name,
              slug: p.slug,
            ),
        ];
      });

  ProductPage _page(List<CatalogProduct> items, int page) {
    final start = (page - 1) * pageSize;
    if (start >= items.length) return const ProductPage(items: []);
    final end = start + pageSize;
    return ProductPage(
      items: items.sublist(start, end.clamp(0, items.length)),
      nextPage: end < items.length ? page + 1 : null,
    );
  }

  /// Server-side ordering stand-in. Prices are compared in paise only to
  /// order the fake data; nothing shown comes from this.
  List<CatalogProduct> _sorted(List<CatalogProduct> items, ProductSort sort) {
    int paise(CatalogProduct p) {
      final parts = p.defaultVariant.sellingPrice.split('.');
      final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
      return int.parse(parts[0]) * 100 + int.parse(fraction);
    }

    final sorted = [...items];
    switch (sort) {
      case ProductSort.relevance:
        break;
      case ProductSort.priceLowToHigh:
        sorted.sort((a, b) => paise(a) - paise(b));
      case ProductSort.priceHighToLow:
        sorted.sort((a, b) => paise(b) - paise(a));
      case ProductSort.discount:
        sorted.sort(
          (a, b) =>
              b.defaultVariant.discountPercent -
              a.defaultVariant.discountPercent,
        );
    }
    return sorted;
  }

  bool _matches(_Product p, String q) =>
      q.isNotEmpty &&
      (p.name.toLowerCase().contains(q) ||
          p.category.replaceAll('-', ' ').contains(q) ||
          p.variants.any((v) => v.name.toLowerCase() == q));

  Set<String> _categorySlugs(String? slug) {
    for (final top in _categories) {
      if (top.slug == slug) {
        return {top.slug, for (final c in top.children) c.slug};
      }
      for (final child in top.children) {
        if (child.slug == slug) return {child.slug};
      }
    }
    return {?slug};
  }

  List<CatalogProduct> _collectionItems(String slug) => switch (slug) {
    'bestsellers' => [
      for (final i in [0, 1, 4, 8, 10]) _card(_products[i]),
    ],
    'offers' => [
      for (final i in [2, 3, 9, 11, 0]) _card(_products[i]),
    ],
    'new-launches' => [
      for (final i in [12, 13, 6]) _card(_products[i]),
    ],
    _ => const [],
  };
}

/// The server's view of a variant's stock: low at 3 or fewer units.
CatalogVariant _variant(_Variant v, {bool detail = false}) {
  final status = v.stock <= 0
      ? StockStatus.outOfStock
      : v.stock <= 3
      ? StockStatus.lowStock
      : StockStatus.inStock;
  return CatalogVariant(
    id: v.id,
    name: v.name,
    sellingPrice: v.price,
    mrp: v.mrp,
    discountAmount: v.save ?? '0.00',
    discountPercent: v.off ?? 0,
    stockStatus: status,
    orderableQuantity: v.stock <= 0
        ? 0
        : (v.stock < v.maxQty ? v.stock : v.maxQty),
    unitsLeft: status == StockStatus.lowStock ? v.stock : null,
    maxQtyPerOrder: v.maxQty,
    unitPrice: v.unitPrice,
    netQuantity: detail ? v.name : null,
  );
}

CatalogProduct _card(_Product p) {
  final variants = [for (final v in p.variants) _variant(v)];
  final defaultVariant = variants.firstWhere(
    (v) => v.inStock,
    orElse: () => variants.first,
  );
  return CatalogProduct(
    id: p.id,
    slug: p.slug,
    name: p.name,
    defaultVariantId: defaultVariant.id,
    variants: variants,
  );
}

class _Variant {
  const _Variant(
    this.id,
    this.name,
    this.price,
    this.mrp, {
    this.off,
    this.save,
    this.stock = 40,
    this.maxQty = 5,
    this.unitPrice,
  });

  final int id;
  final String name;
  final String price;
  final String mrp;
  final int? off;
  final String? save;
  final int stock;
  final int maxQty;
  final UnitPrice? unitPrice;
}

class _Product {
  const _Product(this.id, this.slug, this.name, this.category, this.variants);

  final int id;
  final String slug;
  final String name;
  final String category;
  final List<_Variant> variants;
}

const _trending = ['olive oil', 'desi ghee', 'canola oil', 'wheatgrass'];

const _categories = [
  ProductCategory(
    id: 1,
    slug: 'edible-oils',
    name: 'Edible Oils',
    children: [
      ProductCategory(id: 11, slug: 'olive-oil', name: 'Olive Oil'),
      ProductCategory(id: 12, slug: 'canola-oil', name: 'Canola Oil'),
      ProductCategory(id: 13, slug: 'mustard-oil', name: 'Mustard Oil'),
      ProductCategory(id: 14, slug: 'other-oils', name: 'Other Oils'),
    ],
  ),
  ProductCategory(
    id: 2,
    slug: 'ghee',
    name: 'Ghee',
    children: [ProductCategory(id: 21, slug: 'desi-ghee', name: 'Desi Ghee')],
  ),
  ProductCategory(
    id: 3,
    slug: 'health-foods',
    name: 'Health Foods',
    children: [
      ProductCategory(id: 31, slug: 'wheatgrass', name: 'Wheatgrass'),
      ProductCategory(id: 32, slug: 'seeds', name: 'Seeds'),
    ],
  ),
  ProductCategory(
    id: 4,
    slug: 'beverages',
    name: 'Beverages',
    children: [
      ProductCategory(id: 41, slug: 'juices', name: 'Juices'),
      ProductCategory(id: 42, slug: 'water', name: 'Water'),
    ],
  ),
];

const _collectionNames = {
  'bestsellers': 'Bestsellers',
  'offers': 'Offers',
  'new-launches': 'New launches',
};

const _banners = [
  HomeBanner(
    id: 1,
    title: 'Up to 20% off on olive oils',
    link: CollectionBannerLink('offers'),
  ),
  HomeBanner(
    id: 2,
    title: 'Pure desi ghee, delivered in minutes',
    link: CategoryBannerLink('ghee'),
  ),
  HomeBanner(
    id: 3,
    title: 'Jivo Canola Oil: heart-healthy cooking',
    link: ProductBannerLink('jivo-canola-oil'),
  ),
];

const _products = [
  _Product(1, 'jivo-canola-oil', 'Jivo Canola Oil', 'canola-oil', [
    _Variant(
      101,
      '1 L',
      '249.00',
      '299.00',
      off: 16,
      save: '50.00',
      unitPrice: (amount: '24.90', per: '100 ml'),
    ),
    _Variant(102, '2 L', '479.00', '580.00', off: 17, save: '101.00'),
    _Variant(103, '5 L', '1149.00', '1399.00', off: 17, save: '250.00'),
  ]),
  _Product(
    2,
    'jivo-extra-light-olive-oil',
    'Jivo Extra Light Olive Oil',
    'olive-oil',
    [
      _Variant(201, '1 L', '899.00', '1099.00', off: 18, save: '200.00'),
      _Variant(202, '2 L', '1749.00', '2150.00', off: 18, save: '401.00'),
    ],
  ),
  _Product(3, 'jivo-pomace-olive-oil', 'Jivo Pomace Olive Oil', 'olive-oil', [
    _Variant(301, '1 L', '649.00', '799.00', off: 18, save: '150.00'),
    _Variant(302, '5 L', '2999.00', '3699.00', off: 18, save: '700.00'),
  ]),
  _Product(
    4,
    'jivo-extra-virgin-olive-oil',
    'Jivo Extra Virgin Olive Oil',
    'olive-oil',
    [
      _Variant(
        401,
        '500 ml',
        '599.00',
        '699.00',
        off: 14,
        save: '100.00',
        stock: 3,
      ),
    ],
  ),
  _Product(
    5,
    'jivo-mustard-oil',
    'Jivo Kachi Ghani Mustard Oil',
    'mustard-oil',
    [
      _Variant(501, '1 L', '189.00', '210.00', off: 10, save: '21.00'),
      _Variant(502, '5 L', '899.00', '1050.00', off: 14, save: '151.00'),
    ],
  ),
  _Product(6, 'jivo-groundnut-oil', 'Jivo Groundnut Oil', 'other-oils', [
    _Variant(601, '1 L', '269.00', '299.00', off: 10, save: '30.00', stock: 0),
  ]),
  _Product(7, 'jivo-rice-bran-oil', 'Jivo Rice Bran Oil', 'other-oils', [
    _Variant(701, '1 L', '199.00', '220.00', off: 9, save: '21.00'),
  ]),
  _Product(8, 'jivo-sunflower-oil', 'Jivo Sunflower Oil', 'other-oils', [
    _Variant(801, '1 L', '169.00', '169.00'),
  ]),
  _Product(9, 'jivo-desi-ghee', 'Jivo Desi Ghee', 'desi-ghee', [
    _Variant(901, '500 ml', '349.00', '385.00', off: 9, save: '36.00'),
    _Variant(902, '1 L', '679.00', '750.00', off: 9, save: '71.00'),
  ]),
  _Product(10, 'jivo-cow-ghee', 'Jivo Cow Ghee', 'desi-ghee', [
    _Variant(1001, '1 L', '699.50', '799.00', off: 12, save: '99.50'),
  ]),
  _Product(
    11,
    'jivo-wheatgrass-powder',
    'Jivo Wheatgrass Powder',
    'wheatgrass',
    [_Variant(1101, '100 g', '299.00', '350.00', off: 14, save: '51.00')],
  ),
  _Product(12, 'jivo-wheatgrass-juice', 'Jivo Wheatgrass Juice', 'juices', [
    _Variant(1201, '500 ml', '199.00', '249.00', off: 20, save: '50.00'),
  ]),
  _Product(13, 'jivo-chia-seeds', 'Jivo Chia Seeds', 'seeds', [
    _Variant(1301, '200 g', '179.00', '199.00', off: 10, save: '20.00'),
  ]),
  _Product(14, 'jivo-flax-seeds', 'Jivo Flax Seeds', 'seeds', [
    _Variant(1401, '250 g', '129.00', '149.00', off: 13, save: '20.00'),
  ]),
  _Product(15, 'jivo-drinking-water', 'Jivo Packaged Drinking Water', 'water', [
    _Variant(1501, '1 L', '20.00', '20.00', maxQty: 12),
  ]),
];
