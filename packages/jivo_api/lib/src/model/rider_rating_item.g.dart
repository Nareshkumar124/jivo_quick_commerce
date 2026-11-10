// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_rating_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderRatingItemCWProxy {
  RiderRatingItem id(int id);

  RiderRatingItem stars(int stars);

  RiderRatingItem tags(List<RatingTagEnum> tags);

  RiderRatingItem ratedAt(DateTime ratedAt);

  RiderRatingItem orderNumber(String orderNumber);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingItem(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingItem call({
    int id,
    int stars,
    List<RatingTagEnum> tags,
    DateTime ratedAt,
    String orderNumber,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderRatingItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderRatingItem.copyWith.fieldName(...)`
class _$RiderRatingItemCWProxyImpl implements _$RiderRatingItemCWProxy {
  const _$RiderRatingItemCWProxyImpl(this._value);

  final RiderRatingItem _value;

  @override
  RiderRatingItem id(int id) => this(id: id);

  @override
  RiderRatingItem stars(int stars) => this(stars: stars);

  @override
  RiderRatingItem tags(List<RatingTagEnum> tags) => this(tags: tags);

  @override
  RiderRatingItem ratedAt(DateTime ratedAt) => this(ratedAt: ratedAt);

  @override
  RiderRatingItem orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingItem(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingItem call({
    Object? id = const $CopyWithPlaceholder(),
    Object? stars = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? ratedAt = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
  }) {
    return RiderRatingItem(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      stars: stars == const $CopyWithPlaceholder()
          ? _value.stars
          // ignore: cast_nullable_to_non_nullable
          : stars as int,
      tags: tags == const $CopyWithPlaceholder()
          ? _value.tags
          // ignore: cast_nullable_to_non_nullable
          : tags as List<RatingTagEnum>,
      ratedAt: ratedAt == const $CopyWithPlaceholder()
          ? _value.ratedAt
          // ignore: cast_nullable_to_non_nullable
          : ratedAt as DateTime,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
    );
  }
}

extension $RiderRatingItemCopyWith on RiderRatingItem {
  /// Returns a callable class that can be used as follows: `instanceOfRiderRatingItem.copyWith(...)` or like so:`instanceOfRiderRatingItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderRatingItemCWProxy get copyWith => _$RiderRatingItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderRatingItem _$RiderRatingItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RiderRatingItem', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['id', 'stars', 'tags', 'rated_at', 'order_number'],
  );
  final val = RiderRatingItem(
    id: $checkedConvert('id', (v) => (v as num).toInt()),
    stars: $checkedConvert('stars', (v) => (v as num).toInt()),
    tags: $checkedConvert(
      'tags',
      (v) => (v as List<dynamic>)
          .map(
            (e) => $enumDecode(
              _$RatingTagEnumEnumMap,
              e,
              unknownValue: RatingTagEnum.unknownDefaultOpenApi,
            ),
          )
          .toList(),
    ),
    ratedAt: $checkedConvert('rated_at', (v) => DateTime.parse(v as String)),
    orderNumber: $checkedConvert('order_number', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'ratedAt': 'rated_at', 'orderNumber': 'order_number'});

Map<String, dynamic> _$RiderRatingItemToJson(RiderRatingItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'stars': instance.stars,
      'tags': instance.tags.map((e) => _$RatingTagEnumEnumMap[e]!).toList(),
      'rated_at': instance.ratedAt.toIso8601String(),
      'order_number': instance.orderNumber,
    };

const _$RatingTagEnumEnumMap = {
  RatingTagEnum.ON_TIME: 'ON_TIME',
  RatingTagEnum.WELL_PACKED: 'WELL_PACKED',
  RatingTagEnum.FRESH_PRODUCTS: 'FRESH_PRODUCTS',
  RatingTagEnum.POLITE_RIDER: 'POLITE_RIDER',
  RatingTagEnum.LATE_DELIVERY: 'LATE_DELIVERY',
  RatingTagEnum.DAMAGED_ITEMS: 'DAMAGED_ITEMS',
  RatingTagEnum.MISSING_ITEMS: 'MISSING_ITEMS',
  RatingTagEnum.RUDE_RIDER: 'RUDE_RIDER',
  RatingTagEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
