// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reorder_issue.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReorderIssueCWProxy {
  ReorderIssue variantId(int variantId);

  ReorderIssue productName(String productName);

  ReorderIssue variantName(String variantName);

  ReorderIssue requestedQuantity(int requestedQuantity);

  ReorderIssue addedQuantity(int addedQuantity);

  ReorderIssue reason(ReorderIssueReasonEnum reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReorderIssue(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReorderIssue(...).copyWith(id: 12, name: "My name")
  /// ````
  ReorderIssue call({
    int variantId,
    String productName,
    String variantName,
    int requestedQuantity,
    int addedQuantity,
    ReorderIssueReasonEnum reason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReorderIssue.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReorderIssue.copyWith.fieldName(...)`
class _$ReorderIssueCWProxyImpl implements _$ReorderIssueCWProxy {
  const _$ReorderIssueCWProxyImpl(this._value);

  final ReorderIssue _value;

  @override
  ReorderIssue variantId(int variantId) => this(variantId: variantId);

  @override
  ReorderIssue productName(String productName) =>
      this(productName: productName);

  @override
  ReorderIssue variantName(String variantName) =>
      this(variantName: variantName);

  @override
  ReorderIssue requestedQuantity(int requestedQuantity) =>
      this(requestedQuantity: requestedQuantity);

  @override
  ReorderIssue addedQuantity(int addedQuantity) =>
      this(addedQuantity: addedQuantity);

  @override
  ReorderIssue reason(ReorderIssueReasonEnum reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReorderIssue(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReorderIssue(...).copyWith(id: 12, name: "My name")
  /// ````
  ReorderIssue call({
    Object? variantId = const $CopyWithPlaceholder(),
    Object? productName = const $CopyWithPlaceholder(),
    Object? variantName = const $CopyWithPlaceholder(),
    Object? requestedQuantity = const $CopyWithPlaceholder(),
    Object? addedQuantity = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return ReorderIssue(
      variantId: variantId == const $CopyWithPlaceholder()
          ? _value.variantId
          // ignore: cast_nullable_to_non_nullable
          : variantId as int,
      productName: productName == const $CopyWithPlaceholder()
          ? _value.productName
          // ignore: cast_nullable_to_non_nullable
          : productName as String,
      variantName: variantName == const $CopyWithPlaceholder()
          ? _value.variantName
          // ignore: cast_nullable_to_non_nullable
          : variantName as String,
      requestedQuantity: requestedQuantity == const $CopyWithPlaceholder()
          ? _value.requestedQuantity
          // ignore: cast_nullable_to_non_nullable
          : requestedQuantity as int,
      addedQuantity: addedQuantity == const $CopyWithPlaceholder()
          ? _value.addedQuantity
          // ignore: cast_nullable_to_non_nullable
          : addedQuantity as int,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as ReorderIssueReasonEnum,
    );
  }
}

extension $ReorderIssueCopyWith on ReorderIssue {
  /// Returns a callable class that can be used as follows: `instanceOfReorderIssue.copyWith(...)` or like so:`instanceOfReorderIssue.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReorderIssueCWProxy get copyWith => _$ReorderIssueCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReorderIssue _$ReorderIssueFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ReorderIssue',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'variant_id',
            'product_name',
            'variant_name',
            'requested_quantity',
            'added_quantity',
            'reason',
          ],
        );
        final val = ReorderIssue(
          variantId: $checkedConvert('variant_id', (v) => (v as num).toInt()),
          productName: $checkedConvert('product_name', (v) => v as String),
          variantName: $checkedConvert('variant_name', (v) => v as String),
          requestedQuantity: $checkedConvert(
            'requested_quantity',
            (v) => (v as num).toInt(),
          ),
          addedQuantity: $checkedConvert(
            'added_quantity',
            (v) => (v as num).toInt(),
          ),
          reason: $checkedConvert(
            'reason',
            (v) => $enumDecode(
              _$ReorderIssueReasonEnumEnumMap,
              v,
              unknownValue: ReorderIssueReasonEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'variantId': 'variant_id',
        'productName': 'product_name',
        'variantName': 'variant_name',
        'requestedQuantity': 'requested_quantity',
        'addedQuantity': 'added_quantity',
      },
    );

Map<String, dynamic> _$ReorderIssueToJson(ReorderIssue instance) =>
    <String, dynamic>{
      'variant_id': instance.variantId,
      'product_name': instance.productName,
      'variant_name': instance.variantName,
      'requested_quantity': instance.requestedQuantity,
      'added_quantity': instance.addedQuantity,
      'reason': _$ReorderIssueReasonEnumEnumMap[instance.reason]!,
    };

const _$ReorderIssueReasonEnumEnumMap = {
  ReorderIssueReasonEnum.OUT_OF_STOCK: 'OUT_OF_STOCK',
  ReorderIssueReasonEnum.LIMITED_STOCK: 'LIMITED_STOCK',
  ReorderIssueReasonEnum.NOT_AVAILABLE: 'NOT_AVAILABLE',
  ReorderIssueReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
