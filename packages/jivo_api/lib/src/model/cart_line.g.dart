// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_line.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartLineCWProxy {
  CartLine id(int id);

  CartLine product(CartProduct product);

  CartLine variant(VariantSummary variant);

  CartLine quantity(int quantity);

  CartLine lineMrpTotal(String lineMrpTotal);

  CartLine lineTotal(String lineTotal);

  CartLine issue(CartLineIssue? issue);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartLine(...).copyWith(id: 12, name: "My name")
  /// ````
  CartLine call({
    int id,
    CartProduct product,
    VariantSummary variant,
    int quantity,
    String lineMrpTotal,
    String lineTotal,
    CartLineIssue? issue,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartLine.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartLine.copyWith.fieldName(...)`
class _$CartLineCWProxyImpl implements _$CartLineCWProxy {
  const _$CartLineCWProxyImpl(this._value);

  final CartLine _value;

  @override
  CartLine id(int id) => this(id: id);

  @override
  CartLine product(CartProduct product) => this(product: product);

  @override
  CartLine variant(VariantSummary variant) => this(variant: variant);

  @override
  CartLine quantity(int quantity) => this(quantity: quantity);

  @override
  CartLine lineMrpTotal(String lineMrpTotal) =>
      this(lineMrpTotal: lineMrpTotal);

  @override
  CartLine lineTotal(String lineTotal) => this(lineTotal: lineTotal);

  @override
  CartLine issue(CartLineIssue? issue) => this(issue: issue);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartLine(...).copyWith(id: 12, name: "My name")
  /// ````
  CartLine call({
    Object? id = const $CopyWithPlaceholder(),
    Object? product = const $CopyWithPlaceholder(),
    Object? variant = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? lineMrpTotal = const $CopyWithPlaceholder(),
    Object? lineTotal = const $CopyWithPlaceholder(),
    Object? issue = const $CopyWithPlaceholder(),
  }) {
    return CartLine(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
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
      lineMrpTotal: lineMrpTotal == const $CopyWithPlaceholder()
          ? _value.lineMrpTotal
          // ignore: cast_nullable_to_non_nullable
          : lineMrpTotal as String,
      lineTotal: lineTotal == const $CopyWithPlaceholder()
          ? _value.lineTotal
          // ignore: cast_nullable_to_non_nullable
          : lineTotal as String,
      issue: issue == const $CopyWithPlaceholder()
          ? _value.issue
          // ignore: cast_nullable_to_non_nullable
          : issue as CartLineIssue?,
    );
  }
}

extension $CartLineCopyWith on CartLine {
  /// Returns a callable class that can be used as follows: `instanceOfCartLine.copyWith(...)` or like so:`instanceOfCartLine.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartLineCWProxy get copyWith => _$CartLineCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartLine _$CartLineFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CartLine',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'product',
        'variant',
        'quantity',
        'line_mrp_total',
        'line_total',
        'issue',
      ],
    );
    final val = CartLine(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      product: $checkedConvert(
        'product',
        (v) => CartProduct.fromJson(v as Map<String, dynamic>),
      ),
      variant: $checkedConvert(
        'variant',
        (v) => VariantSummary.fromJson(v as Map<String, dynamic>),
      ),
      quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
      lineMrpTotal: $checkedConvert('line_mrp_total', (v) => v as String),
      lineTotal: $checkedConvert('line_total', (v) => v as String),
      issue: $checkedConvert(
        'issue',
        (v) => v == null
            ? null
            : CartLineIssue.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'lineMrpTotal': 'line_mrp_total',
    'lineTotal': 'line_total',
  },
);

Map<String, dynamic> _$CartLineToJson(CartLine instance) => <String, dynamic>{
  'id': instance.id,
  'product': instance.product.toJson(),
  'variant': instance.variant.toJson(),
  'quantity': instance.quantity,
  'line_mrp_total': instance.lineMrpTotal,
  'line_total': instance.lineTotal,
  'issue': instance.issue?.toJson(),
};
