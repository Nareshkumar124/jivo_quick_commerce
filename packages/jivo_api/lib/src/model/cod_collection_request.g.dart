// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cod_collection_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CodCollectionRequestCWProxy {
  CodCollectionRequest mode(CodModeEnum mode);

  CodCollectionRequest amount(String amount);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CodCollectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CodCollectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CodCollectionRequest call({CodModeEnum mode, String amount});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCodCollectionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCodCollectionRequest.copyWith.fieldName(...)`
class _$CodCollectionRequestCWProxyImpl
    implements _$CodCollectionRequestCWProxy {
  const _$CodCollectionRequestCWProxyImpl(this._value);

  final CodCollectionRequest _value;

  @override
  CodCollectionRequest mode(CodModeEnum mode) => this(mode: mode);

  @override
  CodCollectionRequest amount(String amount) => this(amount: amount);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CodCollectionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CodCollectionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CodCollectionRequest call({
    Object? mode = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
  }) {
    return CodCollectionRequest(
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as CodModeEnum,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
    );
  }
}

extension $CodCollectionRequestCopyWith on CodCollectionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCodCollectionRequest.copyWith(...)` or like so:`instanceOfCodCollectionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CodCollectionRequestCWProxy get copyWith =>
      _$CodCollectionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CodCollectionRequest _$CodCollectionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CodCollectionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['mode', 'amount']);
  final val = CodCollectionRequest(
    mode: $checkedConvert(
      'mode',
      (v) => $enumDecode(
        _$CodModeEnumEnumMap,
        v,
        unknownValue: CodModeEnum.unknownDefaultOpenApi,
      ),
    ),
    amount: $checkedConvert('amount', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CodCollectionRequestToJson(
  CodCollectionRequest instance,
) => <String, dynamic>{
  'mode': _$CodModeEnumEnumMap[instance.mode]!,
  'amount': instance.amount,
};

const _$CodModeEnumEnumMap = {
  CodModeEnum.cash: 'cash',
  CodModeEnum.upi: 'upi',
  CodModeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
