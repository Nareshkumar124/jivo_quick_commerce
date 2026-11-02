// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_delete_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AccountDeleteRequestCWProxy {
  AccountDeleteRequest otp(String otp);

  AccountDeleteRequest reason(String? reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AccountDeleteRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AccountDeleteRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  AccountDeleteRequest call({String otp, String? reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAccountDeleteRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAccountDeleteRequest.copyWith.fieldName(...)`
class _$AccountDeleteRequestCWProxyImpl
    implements _$AccountDeleteRequestCWProxy {
  const _$AccountDeleteRequestCWProxyImpl(this._value);

  final AccountDeleteRequest _value;

  @override
  AccountDeleteRequest otp(String otp) => this(otp: otp);

  @override
  AccountDeleteRequest reason(String? reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AccountDeleteRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AccountDeleteRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  AccountDeleteRequest call({
    Object? otp = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
  }) {
    return AccountDeleteRequest(
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as String,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
    );
  }
}

extension $AccountDeleteRequestCopyWith on AccountDeleteRequest {
  /// Returns a callable class that can be used as follows: `instanceOfAccountDeleteRequest.copyWith(...)` or like so:`instanceOfAccountDeleteRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AccountDeleteRequestCWProxy get copyWith =>
      _$AccountDeleteRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDeleteRequest _$AccountDeleteRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AccountDeleteRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['otp']);
  final val = AccountDeleteRequest(
    otp: $checkedConvert('otp', (v) => v as String),
    reason: $checkedConvert('reason', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$AccountDeleteRequestToJson(
  AccountDeleteRequest instance,
) => <String, dynamic>{'otp': instance.otp, 'reason': ?instance.reason};
