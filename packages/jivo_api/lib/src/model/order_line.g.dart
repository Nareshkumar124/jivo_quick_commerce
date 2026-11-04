// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_line.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderLineCWProxy {
  OrderLine id(int id);

  OrderLine variantId(int variantId);

  OrderLine productId(int productId);

  OrderLine productName(String productName);

  OrderLine variantName(String variantName);

  OrderLine image(ImageSet? image);

  OrderLine mrp(String mrp);

  OrderLine sellingPrice(String sellingPrice);

  OrderLine quantity(int quantity);

  OrderLine lineMrpTotal(String lineMrpTotal);

  OrderLine lineTotal(String lineTotal);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderLine(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderLine call({
    int id,
    int variantId,
    int productId,
    String productName,
    String variantName,
    ImageSet? image,
    String mrp,
    String sellingPrice,
    int quantity,
    String lineMrpTotal,
    String lineTotal,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderLine.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderLine.copyWith.fieldName(...)`
class _$OrderLineCWProxyImpl implements _$OrderLineCWProxy {
  const _$OrderLineCWProxyImpl(this._value);

  final OrderLine _value;

  @override
  OrderLine id(int id) => this(id: id);

  @override
  OrderLine variantId(int variantId) => this(variantId: variantId);

  @override
  OrderLine productId(int productId) => this(productId: productId);

  @override
  OrderLine productName(String productName) => this(productName: productName);

  @override
  OrderLine variantName(String variantName) => this(variantName: variantName);

  @override
  OrderLine image(ImageSet? image) => this(image: image);

  @override
  OrderLine mrp(String mrp) => this(mrp: mrp);

  @override
  OrderLine sellingPrice(String sellingPrice) =>
      this(sellingPrice: sellingPrice);

  @override
  OrderLine quantity(int quantity) => this(quantity: quantity);

  @override
  OrderLine lineMrpTotal(String lineMrpTotal) =>
      this(lineMrpTotal: lineMrpTotal);

  @override
  OrderLine lineTotal(String lineTotal) => this(lineTotal: lineTotal);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderLine(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderLine call({
    Object? id = const $CopyWithPlaceholder(),
    Object? variantId = const $CopyWithPlaceholder(),
    Object? productId = const $CopyWithPlaceholder(),
    Object? productName = const $CopyWithPlaceholder(),
    Object? variantName = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
    Object? mrp = const $CopyWithPlaceholder(),
    Object? sellingPrice = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? lineMrpTotal = const $CopyWithPlaceholder(),
    Object? lineTotal = const $CopyWithPlaceholder(),
  }) {
    return OrderLine(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      variantId: variantId == const $CopyWithPlaceholder()
          ? _value.variantId
          // ignore: cast_nullable_to_non_nullable
          : variantId as int,
      productId: productId == const $CopyWithPlaceholder()
          ? _value.productId
          // ignore: cast_nullable_to_non_nullable
          : productId as int,
      productName: productName == const $CopyWithPlaceholder()
          ? _value.productName
          // ignore: cast_nullable_to_non_nullable
          : productName as String,
      variantName: variantName == const $CopyWithPlaceholder()
          ? _value.variantName
          // ignore: cast_nullable_to_non_nullable
          : variantName as String,
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet?,
      mrp: mrp == const $CopyWithPlaceholder()
          ? _value.mrp
          // ignore: cast_nullable_to_non_nullable
          : mrp as String,
      sellingPrice: sellingPrice == const $CopyWithPlaceholder()
          ? _value.sellingPrice
          // ignore: cast_nullable_to_non_nullable
          : sellingPrice as String,
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
    );
  }
}

extension $OrderLineCopyWith on OrderLine {
  /// Returns a callable class that can be used as follows: `instanceOfOrderLine.copyWith(...)` or like so:`instanceOfOrderLine.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderLineCWProxy get copyWith => _$OrderLineCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderLine _$OrderLineFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OrderLine',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'variant_id',
        'product_id',
        'product_name',
        'variant_name',
        'image',
        'mrp',
        'selling_price',
        'quantity',
        'line_mrp_total',
        'line_total',
      ],
    );
    final val = OrderLine(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      variantId: $checkedConvert('variant_id', (v) => (v as num).toInt()),
      productId: $checkedConvert('product_id', (v) => (v as num).toInt()),
      productName: $checkedConvert('product_name', (v) => v as String),
      variantName: $checkedConvert('variant_name', (v) => v as String),
      image: $checkedConvert(
        'image',
        (v) => v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
      ),
      mrp: $checkedConvert('mrp', (v) => v as String),
      sellingPrice: $checkedConvert('selling_price', (v) => v as String),
      quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
      lineMrpTotal: $checkedConvert('line_mrp_total', (v) => v as String),
      lineTotal: $checkedConvert('line_total', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'variantId': 'variant_id',
    'productId': 'product_id',
    'productName': 'product_name',
    'variantName': 'variant_name',
    'sellingPrice': 'selling_price',
    'lineMrpTotal': 'line_mrp_total',
    'lineTotal': 'line_total',
  },
);

Map<String, dynamic> _$OrderLineToJson(OrderLine instance) => <String, dynamic>{
  'id': instance.id,
  'variant_id': instance.variantId,
  'product_id': instance.productId,
  'product_name': instance.productName,
  'variant_name': instance.variantName,
  'image': instance.image?.toJson(),
  'mrp': instance.mrp,
  'selling_price': instance.sellingPrice,
  'quantity': instance.quantity,
  'line_mrp_total': instance.lineMrpTotal,
  'line_total': instance.lineTotal,
};
