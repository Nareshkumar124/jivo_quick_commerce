// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'phone_otp_send_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PhoneOtpSendRequestCWProxy {
  PhoneOtpSendRequest phone(String phone);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PhoneOtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PhoneOtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PhoneOtpSendRequest call({String phone});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPhoneOtpSendRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPhoneOtpSendRequest.copyWith.fieldName(...)`
class _$PhoneOtpSendRequestCWProxyImpl implements _$PhoneOtpSendRequestCWProxy {
  const _$PhoneOtpSendRequestCWProxyImpl(this._value);

  final PhoneOtpSendRequest _value;

  @override
  PhoneOtpSendRequest phone(String phone) => this(phone: phone);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PhoneOtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PhoneOtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PhoneOtpSendRequest call({Object? phone = const $CopyWithPlaceholder()}) {
    return PhoneOtpSendRequest(
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
    );
  }
}

extension $PhoneOtpSendRequestCopyWith on PhoneOtpSendRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPhoneOtpSendRequest.copyWith(...)` or like so:`instanceOfPhoneOtpSendRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PhoneOtpSendRequestCWProxy get copyWith =>
      _$PhoneOtpSendRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PhoneOtpSendRequest _$PhoneOtpSendRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PhoneOtpSendRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['phone']);
      final val = PhoneOtpSendRequest(
        phone: $checkedConvert('phone', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$PhoneOtpSendRequestToJson(
  PhoneOtpSendRequest instance,
) => <String, dynamic>{'phone': instance.phone};
