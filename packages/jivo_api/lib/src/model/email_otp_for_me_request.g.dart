// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_otp_for_me_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EmailOtpForMeRequestCWProxy {
  EmailOtpForMeRequest email(String email);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpForMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpForMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpForMeRequest call({String email});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEmailOtpForMeRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEmailOtpForMeRequest.copyWith.fieldName(...)`
class _$EmailOtpForMeRequestCWProxyImpl
    implements _$EmailOtpForMeRequestCWProxy {
  const _$EmailOtpForMeRequestCWProxyImpl(this._value);

  final EmailOtpForMeRequest _value;

  @override
  EmailOtpForMeRequest email(String email) => this(email: email);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpForMeRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpForMeRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpForMeRequest call({Object? email = const $CopyWithPlaceholder()}) {
    return EmailOtpForMeRequest(
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
    );
  }
}

extension $EmailOtpForMeRequestCopyWith on EmailOtpForMeRequest {
  /// Returns a callable class that can be used as follows: `instanceOfEmailOtpForMeRequest.copyWith(...)` or like so:`instanceOfEmailOtpForMeRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EmailOtpForMeRequestCWProxy get copyWith =>
      _$EmailOtpForMeRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailOtpForMeRequest _$EmailOtpForMeRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EmailOtpForMeRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['email']);
  final val = EmailOtpForMeRequest(
    email: $checkedConvert('email', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$EmailOtpForMeRequestToJson(
  EmailOtpForMeRequest instance,
) => <String, dynamic>{'email': instance.email};
