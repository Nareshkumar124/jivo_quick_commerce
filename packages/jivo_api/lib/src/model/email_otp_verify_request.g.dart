// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_otp_verify_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EmailOtpVerifyRequestCWProxy {
  EmailOtpVerifyRequest email(String email);

  EmailOtpVerifyRequest otp(String otp);

  EmailOtpVerifyRequest app(AppEnum app);

  EmailOtpVerifyRequest termsVersion(String termsVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpVerifyRequest call({
    String email,
    String otp,
    AppEnum app,
    String termsVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEmailOtpVerifyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEmailOtpVerifyRequest.copyWith.fieldName(...)`
class _$EmailOtpVerifyRequestCWProxyImpl
    implements _$EmailOtpVerifyRequestCWProxy {
  const _$EmailOtpVerifyRequestCWProxyImpl(this._value);

  final EmailOtpVerifyRequest _value;

  @override
  EmailOtpVerifyRequest email(String email) => this(email: email);

  @override
  EmailOtpVerifyRequest otp(String otp) => this(otp: otp);

  @override
  EmailOtpVerifyRequest app(AppEnum app) => this(app: app);

  @override
  EmailOtpVerifyRequest termsVersion(String termsVersion) =>
      this(termsVersion: termsVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpVerifyRequest call({
    Object? email = const $CopyWithPlaceholder(),
    Object? otp = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? termsVersion = const $CopyWithPlaceholder(),
  }) {
    return EmailOtpVerifyRequest(
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as String,
      app: app == const $CopyWithPlaceholder()
          ? _value.app
          // ignore: cast_nullable_to_non_nullable
          : app as AppEnum,
      termsVersion: termsVersion == const $CopyWithPlaceholder()
          ? _value.termsVersion
          // ignore: cast_nullable_to_non_nullable
          : termsVersion as String,
    );
  }
}

extension $EmailOtpVerifyRequestCopyWith on EmailOtpVerifyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfEmailOtpVerifyRequest.copyWith(...)` or like so:`instanceOfEmailOtpVerifyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EmailOtpVerifyRequestCWProxy get copyWith =>
      _$EmailOtpVerifyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailOtpVerifyRequest _$EmailOtpVerifyRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EmailOtpVerifyRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['email', 'otp', 'app', 'terms_version'],
  );
  final val = EmailOtpVerifyRequest(
    email: $checkedConvert('email', (v) => v as String),
    otp: $checkedConvert('otp', (v) => v as String),
    app: $checkedConvert(
      'app',
      (v) => $enumDecode(
        _$AppEnumEnumMap,
        v,
        unknownValue: AppEnum.unknownDefaultOpenApi,
      ),
    ),
    termsVersion: $checkedConvert('terms_version', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'termsVersion': 'terms_version'});

Map<String, dynamic> _$EmailOtpVerifyRequestToJson(
  EmailOtpVerifyRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'otp': instance.otp,
  'app': _$AppEnumEnumMap[instance.app]!,
  'terms_version': instance.termsVersion,
};

const _$AppEnumEnumMap = {
  AppEnum.customer: 'customer',
  AppEnum.rider: 'rider',
  AppEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
