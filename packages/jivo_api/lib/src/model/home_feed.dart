// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/collection_rail.dart';
import 'package:jivo_api/src/model/store_status.dart';
import 'package:jivo_api/src/model/home_banner.dart';
import 'package:jivo_api/src/model/category_tile.dart';
import 'package:jivo_api/src/model/product_card.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'home_feed.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HomeFeed {
  /// Returns a new [HomeFeed] instance.
  HomeFeed({
    required this.store,

    required this.banners,

    required this.categories,

    required this.collections,

    required this.buyAgain,
  });

  /// Current status of the store in `X-Store-Id` (store-closed banner).
  @JsonKey(name: r'store', required: true, includeIfNull: false)
  final StoreStatus store;

  /// Active banners for this store, in admin order (auto-scrolling carousel).
  @JsonKey(name: r'banners', required: true, includeIfNull: false)
  final List<HomeBanner> banners;

  /// Top-level categories with products at this store, in admin order.
  @JsonKey(name: r'categories', required: true, includeIfNull: false)
  final List<CategoryTile> categories;

  /// Collections shown on home for this store, in admin order. Empty rails omitted.
  @JsonKey(name: r'collections', required: true, includeIfNull: false)
  final List<CollectionRail> collections;

  /// 'Previously bought': up to 10 variants from the user's delivered orders that this store sells, most recent first (`default_variant_id` is the bought variant). Empty when anonymous or without history (hide the rail).
  @JsonKey(name: r'buy_again', required: true, includeIfNull: false)
  final List<ProductCard> buyAgain;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeFeed &&
          other.store == store &&
          other.banners == banners &&
          other.categories == categories &&
          other.collections == collections &&
          other.buyAgain == buyAgain;

  @override
  int get hashCode =>
      store.hashCode +
      banners.hashCode +
      categories.hashCode +
      collections.hashCode +
      buyAgain.hashCode;

  factory HomeFeed.fromJson(Map<String, dynamic> json) =>
      _$HomeFeedFromJson(json);

  Map<String, dynamic> toJson() => _$HomeFeedToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
