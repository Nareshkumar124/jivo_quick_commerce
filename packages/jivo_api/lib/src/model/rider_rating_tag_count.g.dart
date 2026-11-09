// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_rating_tag_count.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderRatingTagCountCWProxy {
  RiderRatingTagCount tag(RatingTagEnum tag);

  RiderRatingTagCount count(int count);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingTagCount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingTagCount(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingTagCount call({RatingTagEnum tag, int count});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderRatingTagCount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderRatingTagCount.copyWith.fieldName(...)`
class _$RiderRatingTagCountCWProxyImpl implements _$RiderRatingTagCountCWProxy {
  const _$RiderRatingTagCountCWProxyImpl(this._value);

  final RiderRatingTagCount _value;

  @override
  RiderRatingTagCount tag(RatingTagEnum tag) => this(tag: tag);

  @override
  RiderRatingTagCount count(int count) => this(count: count);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingTagCount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingTagCount(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingTagCount call({
    Object? tag = const $CopyWithPlaceholder(),
    Object? count = const $CopyWithPlaceholder(),
  }) {
    return RiderRatingTagCount(
      tag: tag == const $CopyWithPlaceholder()
          ? _value.tag
          // ignore: cast_nullable_to_non_nullable
          : tag as RatingTagEnum,
      count: count == const $CopyWithPlaceholder()
          ? _value.count
          // ignore: cast_nullable_to_non_nullable
          : count as int,
    );
  }
}

extension $RiderRatingTagCountCopyWith on RiderRatingTagCount {
  /// Returns a callable class that can be used as follows: `instanceOfRiderRatingTagCount.copyWith(...)` or like so:`instanceOfRiderRatingTagCount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderRatingTagCountCWProxy get copyWith =>
      _$RiderRatingTagCountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderRatingTagCount _$RiderRatingTagCountFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RiderRatingTagCount', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['tag', 'count']);
      final val = RiderRatingTagCount(
        tag: $checkedConvert(
          'tag',
          (v) => $enumDecode(
            _$RatingTagEnumEnumMap,
            v,
            unknownValue: RatingTagEnum.unknownDefaultOpenApi,
          ),
        ),
        count: $checkedConvert('count', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$RiderRatingTagCountToJson(
  RiderRatingTagCount instance,
) => <String, dynamic>{
  'tag': _$RatingTagEnumEnumMap[instance.tag]!,
  'count': instance.count,
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
