// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer_reject_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OfferRejectRequestCWProxy {
  OfferRejectRequest reason(OfferRejectReasonEnum? reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OfferRejectRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OfferRejectRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OfferRejectRequest call({OfferRejectReasonEnum? reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOfferRejectRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOfferRejectRequest.copyWith.fieldName(...)`
class _$OfferRejectRequestCWProxyImpl implements _$OfferRejectRequestCWProxy {
  const _$OfferRejectRequestCWProxyImpl(this._value);

  final OfferRejectRequest _value;

  @override
  OfferRejectRequest reason(OfferRejectReasonEnum? reason) =>
      this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OfferRejectRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OfferRejectRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OfferRejectRequest call({Object? reason = const $CopyWithPlaceholder()}) {
    return OfferRejectRequest(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as OfferRejectReasonEnum?,
    );
  }
}

extension $OfferRejectRequestCopyWith on OfferRejectRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOfferRejectRequest.copyWith(...)` or like so:`instanceOfOfferRejectRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OfferRejectRequestCWProxy get copyWith =>
      _$OfferRejectRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfferRejectRequest _$OfferRejectRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OfferRejectRequest', json, ($checkedConvert) {
      final val = OfferRejectRequest(
        reason: $checkedConvert(
          'reason',
          (v) => $enumDecodeNullable(
            _$OfferRejectReasonEnumEnumMap,
            v,
            unknownValue: OfferRejectReasonEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$OfferRejectRequestToJson(OfferRejectRequest instance) =>
    <String, dynamic>{
      'reason': ?_$OfferRejectReasonEnumEnumMap[instance.reason],
    };

const _$OfferRejectReasonEnumEnumMap = {
  OfferRejectReasonEnum.TOO_FAR: 'TOO_FAR',
  OfferRejectReasonEnum.VEHICLE_ISSUE: 'VEHICLE_ISSUE',
  OfferRejectReasonEnum.ON_BREAK: 'ON_BREAK',
  OfferRejectReasonEnum.OTHER: 'OTHER',
  OfferRejectReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
