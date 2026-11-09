// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_rating_create_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderRatingCreateRequestCWProxy {
  OrderRatingCreateRequest orderStars(int orderStars);

  OrderRatingCreateRequest riderStars(int? riderStars);

  OrderRatingCreateRequest tags(List<RatingTagEnum>? tags);

  OrderRatingCreateRequest comment(String? comment);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRatingCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRatingCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRatingCreateRequest call({
    int orderStars,
    int? riderStars,
    List<RatingTagEnum>? tags,
    String? comment,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderRatingCreateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderRatingCreateRequest.copyWith.fieldName(...)`
class _$OrderRatingCreateRequestCWProxyImpl
    implements _$OrderRatingCreateRequestCWProxy {
  const _$OrderRatingCreateRequestCWProxyImpl(this._value);

  final OrderRatingCreateRequest _value;

  @override
  OrderRatingCreateRequest orderStars(int orderStars) =>
      this(orderStars: orderStars);

  @override
  OrderRatingCreateRequest riderStars(int? riderStars) =>
      this(riderStars: riderStars);

  @override
  OrderRatingCreateRequest tags(List<RatingTagEnum>? tags) => this(tags: tags);

  @override
  OrderRatingCreateRequest comment(String? comment) => this(comment: comment);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderRatingCreateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderRatingCreateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderRatingCreateRequest call({
    Object? orderStars = const $CopyWithPlaceholder(),
    Object? riderStars = const $CopyWithPlaceholder(),
    Object? tags = const $CopyWithPlaceholder(),
    Object? comment = const $CopyWithPlaceholder(),
  }) {
    return OrderRatingCreateRequest(
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
          : tags as List<RatingTagEnum>?,
      comment: comment == const $CopyWithPlaceholder()
          ? _value.comment
          // ignore: cast_nullable_to_non_nullable
          : comment as String?,
    );
  }
}

extension $OrderRatingCreateRequestCopyWith on OrderRatingCreateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOrderRatingCreateRequest.copyWith(...)` or like so:`instanceOfOrderRatingCreateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderRatingCreateRequestCWProxy get copyWith =>
      _$OrderRatingCreateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderRatingCreateRequest _$OrderRatingCreateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'OrderRatingCreateRequest',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['order_stars']);
    final val = OrderRatingCreateRequest(
      orderStars: $checkedConvert('order_stars', (v) => (v as num).toInt()),
      riderStars: $checkedConvert('rider_stars', (v) => (v as num?)?.toInt()),
      tags: $checkedConvert(
        'tags',
        (v) => (v as List<dynamic>?)
            ?.map(
              (e) => $enumDecode(
                _$RatingTagEnumEnumMap,
                e,
                unknownValue: RatingTagEnum.unknownDefaultOpenApi,
              ),
            )
            .toList(),
      ),
      comment: $checkedConvert('comment', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {'orderStars': 'order_stars', 'riderStars': 'rider_stars'},
);

Map<String, dynamic> _$OrderRatingCreateRequestToJson(
  OrderRatingCreateRequest instance,
) => <String, dynamic>{
  'order_stars': instance.orderStars,
  'rider_stars': ?instance.riderStars,
  'tags': ?instance.tags?.map((e) => _$RatingTagEnumEnumMap[e]!).toList(),
  'comment': ?instance.comment,
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
