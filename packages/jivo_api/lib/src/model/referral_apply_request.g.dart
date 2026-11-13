// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referral_apply_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReferralApplyRequestCWProxy {
  ReferralApplyRequest code(String code);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReferralApplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReferralApplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReferralApplyRequest call({String code});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReferralApplyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReferralApplyRequest.copyWith.fieldName(...)`
class _$ReferralApplyRequestCWProxyImpl
    implements _$ReferralApplyRequestCWProxy {
  const _$ReferralApplyRequestCWProxyImpl(this._value);

  final ReferralApplyRequest _value;

  @override
  ReferralApplyRequest code(String code) => this(code: code);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReferralApplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReferralApplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ReferralApplyRequest call({Object? code = const $CopyWithPlaceholder()}) {
    return ReferralApplyRequest(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
    );
  }
}

extension $ReferralApplyRequestCopyWith on ReferralApplyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfReferralApplyRequest.copyWith(...)` or like so:`instanceOfReferralApplyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReferralApplyRequestCWProxy get copyWith =>
      _$ReferralApplyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReferralApplyRequest _$ReferralApplyRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReferralApplyRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['code']);
  final val = ReferralApplyRequest(
    code: $checkedConvert('code', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$ReferralApplyRequestToJson(
  ReferralApplyRequest instance,
) => <String, dynamic>{'code': instance.code};
