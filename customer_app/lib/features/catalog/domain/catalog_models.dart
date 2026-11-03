import 'package:flutter/foundation.dart';

import '../../location/domain/delivery_location.dart';

/// Catalog types the screens render (`03 §2.5`–`§2.7`, `07 §2.3`).
///
/// They follow the Phase 2 contract (`backend/openapi/schema.yaml`:
/// `ProductCard`, `VariantSummary`, `VariantDetail`, `ProductDetail`,
/// `HomeFeed`, `CategoryTree`, `SearchSuggestions`).
/// `ApiCatalogRepository` maps the generated `jivo_api` models into these,
/// so the widgets don't depend on the generated client.
///
/// Money fields are the API's decimal strings (`"249.00"`) and are only ever
/// formatted with `formatRupees`. Prices, discounts, savings and the stepper
/// cap all come from the server; the app derives none of them.

/// `StockStatusEnum`.
enum StockStatus { inStock, lowStock, outOfStock }

/// `UnitPrice`: e.g. ₹27.90 per 100 ml (Legal Metrology).
typedef UnitPrice = ({String amount, String per});

/// A sellable variant (SKU) with its price and stock at the store
/// (`VariantSummary`; the detail-page fields are filled from
/// `VariantDetail`).
@immutable
class CatalogVariant {
  const CatalogVariant({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.mrp,
    required this.stockStatus,
    required this.orderableQuantity,
    required this.maxQtyPerOrder,
    this.discountAmount = '0.00',
    this.discountPercent = 0,
    this.unitsLeft,
    this.unitPrice,
    this.imageUrl,
    this.images = const [],
    this.netQuantity,
  });

  final int id;

  /// e.g. "1 L".
  final String name;
  final String sellingPrice;
  final String mrp;

  /// `mrp - selling_price` as computed by the server; "0.00" when none.
  final String discountAmount;

  /// Whole percent off, from the server; the badge shows when above 0.
  final int discountPercent;
  final StockStatus stockStatus;

  /// Units the customer can add now: the server's
  /// `min(stock, max_qty_per_order)`. The stepper caps here; 0 means out of
  /// stock.
  final int orderableQuantity;

  /// Set only for [StockStatus.lowStock]: "Only 2 left".
  final int? unitsLeft;
  final int maxQtyPerOrder;
  final UnitPrice? unitPrice;
  final String? imageUrl;

  /// Detail page only: the gallery when this variant is selected.
  final List<String> images;

  /// Detail page only: net quantity as on the pack.
  final String? netQuantity;

  bool get inStock =>
      stockStatus != StockStatus.outOfStock && orderableQuantity > 0;

  /// The ADD stepper's cap.
  int get maxSelectable => orderableQuantity < 0 ? 0 : orderableQuantity;

  /// Units for "Only N left", or null.
  int? get lowStockUnits =>
      stockStatus == StockStatus.lowStock ? unitsLeft : null;
}

/// A product tile (`ProductCard`, `03 §2.5`): rails, lists, search,
/// collections, similar products.
@immutable
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.defaultVariantId,
    required this.variants,
    this.brand = 'Jivo',
    this.isVeg = true,
    this.imageUrl,
  }) : assert(variants.length > 0, 'a card always has a variant');

  final int id;
  final String slug;
  final String name;
  final String brand;
  final bool isVeg;

  /// Image of the default variant.
  final String? imageUrl;

  /// The variant the tile shows and ADD adds.
  final int defaultVariantId;

  /// Every variant the store sells, in display order. With more than one,
  /// ADD opens a variant picker.
  final List<CatalogVariant> variants;

  CatalogVariant get defaultVariant => variants.firstWhere(
    (v) => v.id == defaultVariantId,
    orElse: () => variants.first,
  );

  bool get hasOptions => variants.length > 1;

  /// Out of stock in every variant: the tile is greyed out.
  bool get inStock => variants.any((v) => v.inStock);
}

/// A category; [children] are its sub-categories (`CategoryNode` /
/// `CategoryTile`, two levels in v1).
@immutable
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.imageUrl,
    this.children = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String? imageUrl;
  final List<ProductCategory> children;
}

/// `sort=` on `GET /products/`.
enum ProductSort {
  relevance('relevance'),
  priceLowToHigh('price_asc'),
  priceHighToLow('price_desc'),
  discount('discount');

  const ProductSort(this.apiValue);

  final String apiValue;
}

/// One page of a paginated product list.
@immutable
class ProductPage {
  const ProductPage({required this.items, this.nextPage, this.title});

  final List<CatalogProduct> items;

  /// The page to load next, or null on the last page.
  final int? nextPage;

  /// The collection name, for collection pages.
  final String? title;
}

/// Where a banner leads (`BannerLinkTypeEnum`).
sealed class BannerLink {
  const BannerLink();
}

class CategoryBannerLink extends BannerLink {
  const CategoryBannerLink(this.slug);
  final String slug;
}

class CollectionBannerLink extends BannerLink {
  const CollectionBannerLink(this.slug);
  final String slug;
}

class ProductBannerLink extends BannerLink {
  const ProductBannerLink(this.slug);
  final String slug;
}

class UrlBannerLink extends BannerLink {
  const UrlBannerLink(this.url);
  final Uri url;
}

class NoBannerLink extends BannerLink {
  const NoBannerLink();
}

@immutable
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    this.link = const NoBannerLink(),
  });

  final int id;

  /// Also the banner's accessibility label.
  final String title;
  final String? imageUrl;
  final BannerLink link;
}

/// A product rail on home (`CollectionRail`).
@immutable
class HomeCollection {
  const HomeCollection({
    required this.slug,
    required this.name,
    required this.items,
    this.hasMore = false,
  });

  final String slug;
  final String name;
  final List<CatalogProduct> items;

  /// The collection has more products: show "See all".
  final bool hasMore;
}

/// `GET /home/`.
@immutable
class HomeFeed {
  const HomeFeed({
    this.store,
    this.banners = const [],
    this.categories = const [],
    this.collections = const [],
    this.buyAgain = const [],
  });

  /// The status of the store in `X-Store-Id` (store-closed banner).
  final StoreInfo? store;
  final List<HomeBanner> banners;
  final List<ProductCategory> categories;
  final List<HomeCollection> collections;

  /// "Previously bought" (signed in, with delivered orders).
  final List<CatalogProduct> buyAgain;

  bool get isEmpty =>
      banners.isEmpty &&
      categories.isEmpty &&
      collections.isEmpty &&
      buyAgain.isEmpty;
}

/// One row of a nutrition table, e.g. ("Energy (kcal)", ["900", "135"]).
@immutable
class NutritionRow {
  const NutritionRow({
    required this.name,
    required this.values,
    this.isSubRow = false,
  });

  final String name;

  /// One value per column; "" means not stated.
  final List<String> values;

  /// Indented under the previous row.
  final bool isSubRow;
}

/// The nutrition table as printed on the label (`NutritionTable`).
@immutable
class NutritionTable {
  const NutritionTable({required this.columns, required this.rows});

  /// e.g. ["Per 100 ml", "Per serving (15 ml)"].
  final List<String> columns;
  final List<NutritionRow> rows;
}

/// Mandatory label information (`09 §4`, FSSAI and Legal Metrology). Empty
/// strings are not shown.
@immutable
class ProductLabel {
  const ProductLabel({
    this.ingredients = '',
    this.nutrition,
    this.shelfLife = '',
    this.storageInstructions = '',
    this.countryOfOrigin = '',
    this.manufacturer = '',
    this.marketer = '',
    this.importer = '',
    this.consumerCare = '',
    this.fssaiLicenseNo = '',
  });

  final String ingredients;
  final NutritionTable? nutrition;
  final String shelfLife;
  final String storageInstructions;
  final String countryOfOrigin;
  final String manufacturer;
  final String marketer;
  final String importer;
  final String consumerCare;
  final String fssaiLicenseNo;
}

/// `GET /products/{id_or_slug}/`.
@immutable
class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.defaultVariantId,
    required this.variants,
    this.brand = 'Jivo',
    this.isVeg = true,
    this.category,
    this.shortDescription = '',
    this.description = '',
    this.highlights = const [],
    this.label = const ProductLabel(),
    this.similar = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String brand;
  final bool isVeg;
  final ProductCategory? category;
  final String shortDescription;

  /// Plain text; paragraphs separated by a blank line.
  final String description;
  final List<String> highlights;

  /// Selected when the page opens.
  final int defaultVariantId;

  /// Chip order, including out-of-stock ones. Never empty.
  final List<CatalogVariant> variants;
  final ProductLabel label;
  final List<CatalogProduct> similar;

  CatalogVariant get defaultVariant => variants.firstWhere(
    (v) => v.id == defaultVariantId,
    orElse: () => variants.first,
  );
}

/// `SearchSuggestionTypeEnum`.
enum SuggestionType { product, category, keyword }

/// A typeahead row (`SearchSuggestion`). A blank query returns the trending
/// searches as [SuggestionType.keyword].
@immutable
class SearchSuggestion {
  const SearchSuggestion({
    required this.type,
    required this.text,
    required this.query,
    this.slug,
    this.imageUrl,
  });

  final SuggestionType type;

  /// What the row shows.
  final String text;

  /// The search to run (and remember) when tapped.
  final String query;

  /// The product or category to open; null for keywords.
  final String? slug;
  final String? imageUrl;
}
