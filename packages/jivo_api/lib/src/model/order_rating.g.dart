// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_rating.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderRatingCWProxy {
  OrderRating orderStars(int orderStars);

  OrderRating riderStars(int? riderStars);

  OrderRating tags(List<RatingTagEnum> tags);

  OrderRating comment(String comment);

  OrderRating createdAt(DateTime createdAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRating(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRating(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRating call({
    int orderStars,
    int? riderStars,
    List<RatingTagEnum> tags,
    String comment,
    DateTime createdAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderRating.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderRating.copyWith.fieldName(...)`
class _$OrderRatingCWProxyImpl implements _$OrderRatingCWProxy {
  const _$OrderRatingCWProxyImpl(this._value);

  final OrderRating _value;

  @override
  OrderRating orderStars(int orderStars) => this(orderStars: orderStars);

  @override
  OrderRating riderStars(int? riderStars) => this(riderStars: riderStars);

  @override
  OrderRating tags(List<RatingTagEnum> tags) => this(tags: tags);

  @override
  OrderRating comment(String comment) => this(comment: comment);

  @override
  OrderRating createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRating(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRating(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRating call({
    Object? orderStars = const $CopyWithPlaceholder(),
    Object? riderStars = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? comment = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
  }) {
    return OrderRating(
      orderStars: orderStars == const $CopyWithPlaceholder()
          ? _value.orderStars
          // ignore: cast_nullable_to_non_nullable
          : orderStars as int,
      riderStars: riderStars == const $CopyWithPlaceholder()
          ? _value.riderStars
          // ignore: cast_nullable_to_non_nullable
          : riderStars as int?,
      tags: tags == const $CopyWithPlaceholder()
          ? _value.tags
          // ignore: cast_nullable_to_non_nullable
          : tags as List<RatingTagEnum>,
      comment: comment == const $CopyWithPlaceholder()
          ? _value.comment
          // ignore: cast_nullable_to_non_nullable
          : comment as String,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
    );
  }
}

extension $OrderRatingCopyWith on OrderRating {
  /// Returns a callable class that can be used as follows: `instanceOfOrderRating.copyWith(...)` or like so:`instanceOfOrderRating.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderRatingCWProxy get copyWith => _$OrderRatingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderRating _$OrderRatingFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OrderRating',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'order_stars',
        'rider_stars',
        'tags',
        'comment',
        'created_at',
      ],
    );
    final val = OrderRating(
      orderStars: $checkedConvert('order_stars', (v) => (v as num).toInt()),
      riderStars: $checkedConvert('rider_stars', (v) => (v as num?)?.toInt()),
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
      comment: $checkedConvert('comment', (v) => v as String),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderStars': 'order_stars',
    'riderStars': 'rider_stars',
    'createdAt': 'created_at',
  },
);

Map<String, dynamic> _$OrderRatingToJson(OrderRating instance) =>
    <String, dynamic>{
      'order_stars': instance.orderStars,
      'rider_stars': instance.riderStars,
      'tags': instance.tags.map((e) => _$RatingTagEnumEnumMap[e]!).toList(),
      'comment': instance.comment,
      'created_at': instance.createdAt.toIso8601String(),
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
