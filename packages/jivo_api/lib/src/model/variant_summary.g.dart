// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$VariantSummaryCWProxy {
  VariantSummary id(int id);

  VariantSummary name(String name);

  VariantSummary mrp(String mrp);

  VariantSummary sellingPrice(String sellingPrice);

  VariantSummary discountAmount(String discountAmount);

  VariantSummary discountPercent(int discountPercent);

  VariantSummary unitPrice(UnitPrice? unitPrice);

  VariantSummary stockStatus(StockStatusEnum stockStatus);

  VariantSummary orderableQuantity(int orderableQuantity);

  VariantSummary unitsLeft(int? unitsLeft);

  VariantSummary maxQtyPerOrder(int maxQtyPerOrder);

  VariantSummary image(ImageSet? image);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VariantSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VariantSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  VariantSummary call({
    int id,
    String name,
    String mrp,
    String sellingPrice,
    String discountAmount,
    int discountPercent,
    UnitPrice? unitPrice,
    StockStatusEnum stockStatus,
    int orderableQuantity,
    int? unitsLeft,
    int maxQtyPerOrder,
    ImageSet? image,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfVariantSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfVariantSummary.copyWith.fieldName(...)`
class _$VariantSummaryCWProxyImpl implements _$VariantSummaryCWProxy {
  const _$VariantSummaryCWProxyImpl(this._value);

  final VariantSummary _value;

  @override
  VariantSummary id(int id) => this(id: id);

  @override
  VariantSummary name(String name) => this(name: name);

  @override
  VariantSummary mrp(String mrp) => this(mrp: mrp);

  @override
  VariantSummary sellingPrice(String sellingPrice) =>
      this(sellingPrice: sellingPrice);

  @override
  VariantSummary discountAmount(String discountAmount) =>
      this(discountAmount: discountAmount);

  @override
  VariantSummary discountPercent(int discountPercent) =>
      this(discountPercent: discountPercent);

  @override
  VariantSummary unitPrice(UnitPrice? unitPrice) => this(unitPrice: unitPrice);

  @override
  VariantSummary stockStatus(StockStatusEnum stockStatus) =>
      this(stockStatus: stockStatus);

  @override
  VariantSummary orderableQuantity(int orderableQuantity) =>
      this(orderableQuantity: orderableQuantity);

  @override
  VariantSummary unitsLeft(int? unitsLeft) => this(unitsLeft: unitsLeft);

  @override
  VariantSummary maxQtyPerOrder(int maxQtyPerOrder) =>
      this(maxQtyPerOrder: maxQtyPerOrder);

  @override
  VariantSummary image(ImageSet? image) => this(image: image);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VariantSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VariantSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  VariantSummary call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? mrp = const $CopyWithPlaceholder(),
    Object? sellingPrice = const $CopyWithPlaceholder(),
    Object? discountAmount = const $CopyWithPlaceholder(),
    Object? discountPercent = const $CopyWithPlaceholder(),
    Object? unitPrice = const $CopyWithPlaceholder(),
    Object? stockStatus = const $CopyWithPlaceholder(),
    Object? orderableQuantity = const $CopyWithPlaceholder(),
    Object? unitsLeft = const $CopyWithPlaceholder(),
    Object? maxQtyPerOrder = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
  }) {
    return VariantSummary(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      mrp: mrp == const $CopyWithPlaceholder()
          ? _value.mrp
          // ignore: cast_nullable_to_non_nullable
          : mrp as String,
      sellingPrice: sellingPrice == const $CopyWithPlaceholder()
          ? _value.sellingPrice
          // ignore: cast_nullable_to_non_nullable
          : sellingPrice as String,
      discountAmount: discountAmount == const $CopyWithPlaceholder()
          ? _value.discountAmount
          // ignore: cast_nullable_to_non_nullable
          : discountAmount as String,
      discountPercent: discountPercent == const $CopyWithPlaceholder()
          ? _value.discountPercent
          // ignore: cast_nullable_to_non_nullable
          : discountPercent as int,
      unitPrice: unitPrice == const $CopyWithPlaceholder()
          ? _value.unitPrice
          // ignore: cast_nullable_to_non_nullable
          : unitPrice as UnitPrice?,
      stockStatus: stockStatus == const $CopyWithPlaceholder()
          ? _value.stockStatus
          // ignore: cast_nullable_to_non_nullable
          : stockStatus as StockStatusEnum,
      orderableQuantity: orderableQuantity == const $CopyWithPlaceholder()
          ? _value.orderableQuantity
          // ignore: cast_nullable_to_non_nullable
          : orderableQuantity as int,
      unitsLeft: unitsLeft == const $CopyWithPlaceholder()
          ? _value.unitsLeft
          // ignore: cast_nullable_to_non_nullable
          : unitsLeft as int?,
      maxQtyPerOrder: maxQtyPerOrder == const $CopyWithPlaceholder()
          ? _value.maxQtyPerOrder
          // ignore: cast_nullable_to_non_nullable
          : maxQtyPerOrder as int,
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet?,
    );
  }
}

extension $VariantSummaryCopyWith on VariantSummary {
  /// Returns a callable class that can be used as follows: `instanceOfVariantSummary.copyWith(...)` or like so:`instanceOfVariantSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$VariantSummaryCWProxy get copyWith => _$VariantSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VariantSummary _$VariantSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'VariantSummary',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'name',
        'mrp',
        'selling_price',
        'discount_amount',
        'discount_percent',
        'unit_price',
        'stock_status',
        'orderable_quantity',
        'units_left',
        'max_qty_per_order',
        'image',
      ],
    );
    final val = VariantSummary(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      name: $checkedConvert('name', (v) => v as String),
      mrp: $checkedConvert('mrp', (v) => v as String),
      sellingPrice: $checkedConvert('selling_price', (v) => v as String),
      discountAmount: $checkedConvert('discount_amount', (v) => v as String),
      discountPercent: $checkedConvert(
        'discount_percent',
        (v) => (v as num).toInt(),
      ),
      unitPrice: $checkedConvert(
        'unit_price',
        (v) => v == null ? null : UnitPrice.fromJson(v as Map<String, dynamic>),
      ),
      stockStatus: $checkedConvert(
        'stock_status',
        (v) => $enumDecode(
          _$StockStatusEnumEnumMap,
          v,
          unknownValue: StockStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      orderableQuantity: $checkedConvert(
        'orderable_quantity',
        (v) => (v as num).toInt(),
      ),
      unitsLeft: $checkedConvert('units_left', (v) => (v as num?)?.toInt()),
      maxQtyPerOrder: $checkedConvert(
        'max_qty_per_order',
        (v) => (v as num).toInt(),
      ),
      image: $checkedConvert(
        'image',
        (v) => v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'sellingPrice': 'selling_price',
    'discountAmount': 'discount_amount',
    'discountPercent': 'discount_percent',
    'unitPrice': 'unit_price',
    'stockStatus': 'stock_status',
    'orderableQuantity': 'orderable_quantity',
    'unitsLeft': 'units_left',
    'maxQtyPerOrder': 'max_qty_per_order',
  },
);

Map<String, dynamic> _$VariantSummaryToJson(VariantSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'mrp': instance.mrp,
      'selling_price': instance.sellingPrice,
      'discount_amount': instance.discountAmount,
      'discount_percent': instance.discountPercent,
      'unit_price': instance.unitPrice?.toJson(),
      'stock_status': _$StockStatusEnumEnumMap[instance.stockStatus]!,
      'orderable_quantity': instance.orderableQuantity,
      'units_left': instance.unitsLeft,
      'max_qty_per_order': instance.maxQtyPerOrder,
      'image': instance.image?.toJson(),
    };

const _$StockStatusEnumEnumMap = {
  StockStatusEnum.IN_STOCK: 'IN_STOCK',
  StockStatusEnum.LOW_STOCK: 'LOW_STOCK',
  StockStatusEnum.OUT_OF_STOCK: 'OUT_OF_STOCK',
  StockStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
