// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_feed.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HomeFeedCWProxy {
  HomeFeed store(StoreStatus store);

  HomeFeed banners(List<HomeBanner> banners);

  HomeFeed categories(List<CategoryTile> categories);

  HomeFeed collections(List<CollectionRail> collections);

  HomeFeed buyAgain(List<ProductCard> buyAgain);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HomeFeed(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HomeFeed(...).copyWith(id: 12, name: "My name")
  /// ````
  HomeFeed call({
    StoreStatus store,
    List<HomeBanner> banners,
    List<CategoryTile> categories,
    List<CollectionRail> collections,
    List<ProductCard> buyAgain,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHomeFeed.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHomeFeed.copyWith.fieldName(...)`
class _$HomeFeedCWProxyImpl implements _$HomeFeedCWProxy {
  const _$HomeFeedCWProxyImpl(this._value);

  final HomeFeed _value;

  @override
  HomeFeed store(StoreStatus store) => this(store: store);

  @override
  HomeFeed banners(List<HomeBanner> banners) => this(banners: banners);

  @override
  HomeFeed categories(List<CategoryTile> categories) =>
      this(categories: categories);

  @override
  HomeFeed collections(List<CollectionRail> collections) =>
      this(collections: collections);

  @override
  HomeFeed buyAgain(List<ProductCard> buyAgain) => this(buyAgain: buyAgain);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HomeFeed(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HomeFeed(...).copyWith(id: 12, name: "My name")
  /// ````
  HomeFeed call({
    Object? store = const $CopyWithPlaceholder(),
    Object? banners = const $CopyWithPlaceholder(),
    Object? categories = const $CopyWithPlaceholder(),
    Object? collections = const $CopyWithPlaceholder(),
    Object? buyAgain = const $CopyWithPlaceholder(),
  }) {
    return HomeFeed(
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as StoreStatus,
      banners: banners == const $CopyWithPlaceholder()
          ? _value.banners
          // ignore: cast_nullable_to_non_nullable
          : banners as List<HomeBanner>,
      categories: categories == const $CopyWithPlaceholder()
          ? _value.categories
          // ignore: cast_nullable_to_non_nullable
          : categories as List<CategoryTile>,
      collections: collections == const $CopyWithPlaceholder()
          ? _value.collections
          // ignore: cast_nullable_to_non_nullable
          : collections as List<CollectionRail>,
      buyAgain: buyAgain == const $CopyWithPlaceholder()
          ? _value.buyAgain
          // ignore: cast_nullable_to_non_nullable
          : buyAgain as List<ProductCard>,
    );
  }
}

extension $HomeFeedCopyWith on HomeFeed {
  /// Returns a callable class that can be used as follows: `instanceOfHomeFeed.copyWith(...)` or like so:`instanceOfHomeFeed.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HomeFeedCWProxy get copyWith => _$HomeFeedCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeFeed _$HomeFeedFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HomeFeed', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'store',
          'banners',
          'categories',
          'collections',
          'buy_again',
        ],
      );
      final val = HomeFeed(
        store: $checkedConvert(
          'store',
          (v) => StoreStatus.fromJson(v as Map<String, dynamic>),
        ),
        banners: $checkedConvert(
          'banners',
          (v) => (v as List<dynamic>)
              .map((e) => HomeBanner.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        categories: $checkedConvert(
          'categories',
          (v) => (v as List<dynamic>)
              .map((e) => CategoryTile.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        collections: $checkedConvert(
          'collections',
          (v) => (v as List<dynamic>)
              .map((e) => CollectionRail.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        buyAgain: $checkedConvert(
          'buy_again',
          (v) => (v as List<dynamic>)
              .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'buyAgain': 'buy_again'});

Map<String, dynamic> _$HomeFeedToJson(HomeFeed instance) => <String, dynamic>{
  'store': instance.store.toJson(),
  'banners': instance.banners.map((e) => e.toJson()).toList(),
  'categories': instance.categories.map((e) => e.toJson()).toList(),
  'collections': instance.collections.map((e) => e.toJson()).toList(),
  'buy_again': instance.buyAgain.map((e) => e.toJson()).toList(),
};
