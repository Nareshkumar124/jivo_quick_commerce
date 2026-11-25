// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'free_line.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FreeLineCWProxy {
  FreeLine product(CartProduct product);

  FreeLine variant(VariantSummary variant);

  FreeLine quantity(int quantity);

  FreeLine mrp(String mrp);

  FreeLine value(String value);

  FreeLine source_(FreeSourceEnum source_);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeLine(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeLine call({
    CartProduct product,
    VariantSummary variant,
    int quantity,
    String mrp,
    String value,
    FreeSourceEnum source_,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFreeLine.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFreeLine.copyWith.fieldName(...)`
class _$FreeLineCWProxyImpl implements _$FreeLineCWProxy {
  const _$FreeLineCWProxyImpl(this._value);

  final FreeLine _value;

  @override
  FreeLine product(CartProduct product) => this(product: product);

  @override
  FreeLine variant(VariantSummary variant) => this(variant: variant);

  @override
  FreeLine quantity(int quantity) => this(quantity: quantity);

  @override
  FreeLine mrp(String mrp) => this(mrp: mrp);

  @override
  FreeLine value(String value) => this(value: value);

  @override
  FreeLine source_(FreeSourceEnum source_) => this(source_: source_);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeLine(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeLine call({
    Object? product = const $CopyWithPlaceholder(),
    Object? variant = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? mrp = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
  }) {
    return FreeLine(
      product: product == const $CopyWithPlaceholder()
          ? _value.product
          // ignore: cast_nullable_to_non_nullable
          : product as CartProduct,
      variant: variant == const $CopyWithPlaceholder()
          ? _value.variant
          // ignore: cast_nullable_to_non_nullable
          : variant as VariantSummary,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as int,
      mrp: mrp == const $CopyWithPlaceholder()
          ? _value.mrp
          // ignore: cast_nullable_to_non_nullable
          : mrp as String,
      value: value == const $CopyWithPlaceholder()
          ? _value.value
          // ignore: cast_nullable_to_non_nullable
          : value as String,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as FreeSourceEnum,
    );
  }
}

extension $FreeLineCopyWith on FreeLine {
  /// Returns a callable class that can be used as follows: `instanceOfFreeLine.copyWith(...)` or like so:`instanceOfFreeLine.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FreeLineCWProxy get copyWith => _$FreeLineCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FreeLine _$FreeLineFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FreeLine', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'product',
          'variant',
          'quantity',
          'mrp',
          'value',
          'source',
        ],
      );
      final val = FreeLine(
        product: $checkedConvert(
          'product',
          (v) => CartProduct.fromJson(v as Map<String, dynamic>),
        ),
        variant: $checkedConvert(
          'variant',
          (v) => VariantSummary.fromJson(v as Map<String, dynamic>),
        ),
        quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
        mrp: $checkedConvert('mrp', (v) => v as String),
        value: $checkedConvert('value', (v) => v as String),
        source_: $checkedConvert(
          'source',
          (v) => $enumDecode(
            _$FreeSourceEnumEnumMap,
            v,
            unknownValue: FreeSourceEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'source_': 'source'});

Map<String, dynamic> _$FreeLineToJson(FreeLine instance) => <String, dynamic>{
  'product': instance.product.toJson(),
  'variant': instance.variant.toJson(),
  'quantity': instance.quantity,
  'mrp': instance.mrp,
  'value': instance.value,
  'source': _$FreeSourceEnumEnumMap[instance.source_]!,
};

const _$FreeSourceEnumEnumMap = {
  FreeSourceEnum.VOLUME_OFFER: 'VOLUME_OFFER',
  FreeSourceEnum.REWARD: 'REWARD',
  FreeSourceEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
