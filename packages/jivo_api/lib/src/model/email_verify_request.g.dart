// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_verify_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EmailVerifyRequestCWProxy {
  EmailVerifyRequest email(String email);

  EmailVerifyRequest otp(String otp);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailVerifyRequest call({String email, String otp});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEmailVerifyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEmailVerifyRequest.copyWith.fieldName(...)`
class _$EmailVerifyRequestCWProxyImpl implements _$EmailVerifyRequestCWProxy {
  const _$EmailVerifyRequestCWProxyImpl(this._value);

  final EmailVerifyRequest _value;

  @override
  EmailVerifyRequest email(String email) => this(email: email);

  @override
  EmailVerifyRequest otp(String otp) => this(otp: otp);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailVerifyRequest call({
    Object? email = const $CopyWithPlaceholder(),
    Object? otp = const $CopyWithPlaceholder(),
  }) {
    return EmailVerifyRequest(
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as String,
    );
  }
}

extension $EmailVerifyRequestCopyWith on EmailVerifyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfEmailVerifyRequest.copyWith(...)` or like so:`instanceOfEmailVerifyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EmailVerifyRequestCWProxy get copyWith =>
      _$EmailVerifyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailVerifyRequest _$EmailVerifyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EmailVerifyRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['email', 'otp']);
      final val = EmailVerifyRequest(
        email: $checkedConvert('email', (v) => v as String),
        otp: $checkedConvert('otp', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$EmailVerifyRequestToJson(EmailVerifyRequest instance) =>
    <String, dynamic>{'email': instance.email, 'otp': instance.otp};
