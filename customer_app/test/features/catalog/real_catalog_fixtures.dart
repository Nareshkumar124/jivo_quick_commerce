import 'package:customer_app/features/catalog/data/api_catalog_repository.dart';
import 'package:dio/dio.dart';

import '../../helpers/fake_http.dart';

/// Server-shaped catalog payloads for the real Jivo catalog (P8): the
/// shapes are copied from `jqc.jivo.in` responses (2026-11-10); the data
/// adds what the full import brings: two-level categories, some without an
/// image, empty categories, long names, six sizes with pouch and bottle
/// variants, variants without an image, selling price == MRP, discounts
/// over 50% and money with paise. Money is always a 2-decimal string.

Map<String, Object?> imageSet(String key, String alt) => {
  'thumbnail': 'https://jqc.jivo.in/media/catalog/products/$key-256.webp',
  'medium': 'https://jqc.jivo.in/media/catalog/products/$key-512.webp',
  'large': 'https://jqc.jivo.in/media/catalog/products/$key-1024.webp',
  'alt_text': alt,
};

Map<String, Object?> realVariant(
  int id,
  String name, {
  required String price,
  required String mrp,
  required String discount,
  required int percent,
  String stock = 'IN_STOCK',
  int orderable = 5,
  int? unitsLeft,
  int minQty = 1,
  Map<String, Object?>? image,
  Map<String, Object?>? unitPrice,
}) => {
  'id': id,
  'name': name,
  'mrp': mrp,
  'selling_price': price,
  'discount_amount': discount,
  'discount_percent': percent,
  'unit_price': unitPrice,
  'stock_status': stock,
  'orderable_quantity': orderable,
  'units_left': unitsLeft,
  'max_qty_per_order': 5,
  'min_qty_per_order': minQty,
  'price_tiers': <Object>[],
  'image': image,
};

const mustardName = 'Jivo Cold Pressed Kachi Ghani Mustard Oil';
const mustardSlug = 'jivo-cold-pressed-kachi-ghani-mustard-oil';
const longName =
    'Jivo Cold Pressed Wood Pressed Lakdi Ghani Groundnut Oil Premium '
    'Family Pack';

/// Six sizes: no discount (selling == MRP), pouch vs bottle, out of stock,
/// low stock, and sizes without an image. The default (1 L Pouch) has no
/// image, so the card has none either.
final mustardVariants = [
  realVariant(
    401,
    '200 ml',
    price: '52.00',
    mrp: '52.00',
    discount: '0.00',
    percent: 0,
  ),
  realVariant(
    402,
    '500 ml',
    price: '125.00',
    mrp: '160.00',
    discount: '35.00',
    percent: 21,
    image: imageSet('mustard-500', 'Mustard Oil 500 ml'),
  ),
  realVariant(
    403,
    '1 L Pouch',
    price: '180.00',
    mrp: '255.00',
    discount: '75.00',
    percent: 29,
    unitPrice: {'amount': '18.00', 'per': '100 ml'},
  ),
  realVariant(
    404,
    '1 L Bottle',
    price: '199.00',
    mrp: '199.00',
    discount: '0.00',
    percent: 0,
    image: imageSet('mustard-1l', 'Mustard Oil 1 L bottle'),
  ),
  realVariant(
    405,
    '2 L',
    price: '360.00',
    mrp: '499.00',
    discount: '139.00',
    percent: 27,
    stock: 'OUT_OF_STOCK',
    orderable: 0,
  ),
  realVariant(
    406,
    '5 L Jar',
    price: '900.00',
    mrp: '1250.00',
    discount: '350.00',
    percent: 28,
    stock: 'LOW_STOCK',
    orderable: 2,
    unitsLeft: 2,
  ),
];

Map<String, Object?> card(
  int id,
  String slug,
  String name,
  List<Map<String, Object?>> variants, {
  int? defaultId,
}) {
  final chosen = defaultId ?? variants.first['id']! as int;
  return {
    'id': id,
    'slug': slug,
    'name': name,
    'brand': 'Jivo',
    'is_veg': true,
    'image': variants.firstWhere((v) => v['id'] == chosen)['image'],
    'default_variant_id': chosen,
    'variants': variants,
  };
}

final mustardCard = card(
  40,
  mustardSlug,
  mustardName,
  mustardVariants,
  defaultId: 403,
);

/// Real `jqc.jivo.in` numbers: 66% and 61% off.
final oliveCard = card(
  4,
  'jivo-extra-light-olive-oil',
  'Jivo Extra Light Olive Oil',
  [
    realVariant(
      80,
      '1 L',
      price: '500.00',
      mrp: '1499.00',
      discount: '999.00',
      percent: 66,
      image: imageSet('elo-1l', 'Extra Light Olive Oil 1 L'),
    ),
    realVariant(
      81,
      '5 L',
      price: '2500.00',
      mrp: '6499.00',
      discount: '3999.00',
      percent: 61,
      image: imageSet('elo-5l', 'Extra Light Olive Oil 5 L'),
    ),
  ],
);

/// One size, no image, no discount.
final chiaCard = card(50, 'jivo-chia-seeds', 'Jivo Chia Seeds', [
  realVariant(
    501,
    '250 g',
    price: '249.00',
    mrp: '249.00',
    discount: '0.00',
    percent: 0,
    unitPrice: {'amount': '99.60', 'per': '100 g'},
  ),
]);

/// Paise in the price.
final gheeCard = card(51, 'jivo-desi-cow-ghee', 'Jivo Desi Cow Ghee', [
  realVariant(
    511,
    '1 L',
    price: '549.50',
    mrp: '649.00',
    discount: '99.50',
    percent: 15,
    image: imageSet('ghee-1l', 'Desi Cow Ghee 1 L'),
  ),
]);

/// A very long name, no image, no discount.
final longCard = card(52, 'jivo-lakdi-ghani-groundnut-oil', longName, [
  realVariant(
    521,
    '1 L Pouch',
    price: '310.00',
    mrp: '310.00',
    discount: '0.00',
    percent: 0,
  ),
]);

Map<String, Object?> tile(
  int id,
  String name,
  String slug, {
  bool image = false,
}) => {
  'id': id,
  'name': name,
  'slug': slug,
  'image': image ? imageSet('cat-$slug', name) : null,
};

/// 15 categories in two levels; most new ones have no image.
final categoryTree = {
  'results': [
    {
      ...tile(1, 'Edible Oils', 'edible-oils', image: true),
      'children': [
        tile(2, 'Canola Oil', 'canola-oil', image: true),
        tile(3, 'Olive Oil', 'olive-oil', image: true),
        tile(5, 'Mustard Oil', 'mustard-oil', image: true),
        tile(
          6,
          'Groundnut, Sunflower & More',
          'groundnut-sunflower-more',
          image: true,
        ),
      ],
    },
    {...tile(10, 'Seeds', 'seeds'), 'children': <Object>[]},
    {...tile(11, 'Ghee and Butter', 'ghee-and-butter'), 'children': <Object>[]},
    {
      ...tile(12, 'Herbs and Spices', 'herbs-and-spices'),
      'children': <Object>[],
    },
    {...tile(13, 'Coffee and Tea', 'coffee-and-tea'), 'children': <Object>[]},
    {...tile(14, 'Honey', 'honey'), 'children': <Object>[]},
    {...tile(15, 'Cereals', 'cereals'), 'children': <Object>[]},
    {
      ...tile(16, 'Beverages', 'beverages'),
      'children': [tile(17, 'Water', 'water'), tile(18, 'Juices', 'juices')],
    },
  ],
};

Map<String, Object?> page(List<Map<String, Object?>> items) => {
  'count': items.length,
  'next': null,
  'previous': null,
  'results': items,
};

Map<String, Object?> mustardDetail() => {
  ...mustardCard,
  'category': tile(5, 'Mustard Oil', 'mustard-oil', image: true),
  'short_description': 'Cold pressed from the first pressing of mustard seeds.',
  'description': 'Strong pungent taste for Indian cooking.',
  'highlights': ['Cold pressed', 'Kachi ghani'],
  'variants': [
    for (final v in mustardVariants)
      {
        ...v,
        'sku': 'JVW-MUS-${v['id']}',
        'net_quantity': v['name'],
        'images': v['image'] == null ? <Object>[] : [v['image']],
      },
  ],
  'ingredients': '',
  'nutrition': null,
  'shelf_life': '',
  'storage_instructions': '',
  'country_of_origin': 'India',
  'manufacturer': '',
  'marketer': '',
  'importer': '',
  'consumer_care': '',
  'fssai_license_no': '',
  'similar_products': [longCard, chiaCard],
};

/// Products by category slug; `honey` exists but is empty.
final productsByCategory = <String, List<Map<String, Object?>>>{
  'edible-oils': [mustardCard, oliveCard, gheeCard, longCard],
  'mustard-oil': [mustardCard, longCard],
  'seeds': [chiaCard],
  'honey': [],
};

const notFound = {
  'error': {
    'code': 'NOT_FOUND',
    'message': 'Category not found.',
    'details': <String, Object>{},
  },
};

/// Answers like the server for the catalog endpoints above.
(int, Object?) realCatalogServer(RequestOptions request) {
  final path = Uri.parse(request.path).path;
  final q = request.queryParameters;
  return switch (path) {
    '/api/v1/home/' => (
      200,
      {
        'store': {
          'id': 1,
          'name': 'Jivo Wellness Pvt. Ltd.',
          'is_open': true,
          'opens_at': null,
        },
        'banners': <Object>[],
        'categories': [
          for (final node in categoryTree['results']!)
            {
              for (final e in node.entries)
                if (e.key != 'children') e.key: e.value,
            },
        ],
        'collections': [
          {
            'id': 1,
            'name': 'Bestsellers',
            'slug': 'bestsellers',
            'products': [mustardCard, oliveCard, chiaCard, longCard, gheeCard],
            'has_more': false,
          },
        ],
        'buy_again': <Object>[],
      },
    ),
    '/api/v1/categories/' => (200, categoryTree),
    '/api/v1/products/' => switch (productsByCategory[q['category']]) {
      final items? => (200, page(items)),
      null => (404, notFound),
    },
    '/api/v1/products/$mustardSlug/' => (200, mustardDetail()),
    '/api/v1/search/' => (200, page([mustardCard, longCard])),
    '/api/v1/search/suggest/' => (
      200,
      {'query': q['q'] ?? '', 'suggestions': <Object>[]},
    ),
    _ => (404, notFound),
  };
}

/// The API catalog repository on [realCatalogServer], for store 1.
ApiCatalogRepository realCatalogRepository([FakeHttp? http]) =>
    ApiCatalogRepository((http ?? FakeHttp(realCatalogServer)).api(), () => 1);
