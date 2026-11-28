// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_verify_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PhoneVerifyRequestCWProxy {
  PhoneVerifyRequest phone(String phone);

  PhoneVerifyRequest otp(String otp);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PhoneVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PhoneVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PhoneVerifyRequest call({String phone, String otp});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPhoneVerifyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPhoneVerifyRequest.copyWith.fieldName(...)`
class _$PhoneVerifyRequestCWProxyImpl implements _$PhoneVerifyRequestCWProxy {
  const _$PhoneVerifyRequestCWProxyImpl(this._value);

  final PhoneVerifyRequest _value;

  @override
  PhoneVerifyRequest phone(String phone) => this(phone: phone);

  @override
  PhoneVerifyRequest otp(String otp) => this(otp: otp);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PhoneVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PhoneVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PhoneVerifyRequest call({
    Object? phone = const $CopyWithPlaceholder(),
    Object? otp = const $CopyWithPlaceholder(),
  }) {
    return PhoneVerifyRequest(
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as String,
    );
  }
}

extension $PhoneVerifyRequestCopyWith on PhoneVerifyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPhoneVerifyRequest.copyWith(...)` or like so:`instanceOfPhoneVerifyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PhoneVerifyRequestCWProxy get copyWith =>
      _$PhoneVerifyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PhoneVerifyRequest _$PhoneVerifyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PhoneVerifyRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['phone', 'otp']);
      final val = PhoneVerifyRequest(
        phone: $checkedConvert('phone', (v) => v as String),
        otp: $checkedConvert('otp', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$PhoneVerifyRequestToJson(PhoneVerifyRequest instance) =>
    <String, dynamic>{'phone': instance.phone, 'otp': instance.otp};
