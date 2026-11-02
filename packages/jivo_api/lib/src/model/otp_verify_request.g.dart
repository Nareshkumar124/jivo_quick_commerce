// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_verify_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OtpVerifyRequestCWProxy {
  OtpVerifyRequest phone(String phone);

  OtpVerifyRequest otp(String otp);

  OtpVerifyRequest app(AppEnum app);

  OtpVerifyRequest termsVersion(String termsVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpVerifyRequest call({
    String phone,
    String otp,
    AppEnum app,
    String termsVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOtpVerifyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOtpVerifyRequest.copyWith.fieldName(...)`
class _$OtpVerifyRequestCWProxyImpl implements _$OtpVerifyRequestCWProxy {
  const _$OtpVerifyRequestCWProxyImpl(this._value);

  final OtpVerifyRequest _value;

  @override
  OtpVerifyRequest phone(String phone) => this(phone: phone);

  @override
  OtpVerifyRequest otp(String otp) => this(otp: otp);

  @override
  OtpVerifyRequest app(AppEnum app) => this(app: app);

  @override
  OtpVerifyRequest termsVersion(String termsVersion) =>
      this(termsVersion: termsVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpVerifyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpVerifyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpVerifyRequest call({
    Object? phone = const $CopyWithPlaceholder(),
    Object? otp = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? termsVersion = const $CopyWithPlaceholder(),
  }) {
    return OtpVerifyRequest(
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
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

extension $OtpVerifyRequestCopyWith on OtpVerifyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOtpVerifyRequest.copyWith(...)` or like so:`instanceOfOtpVerifyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OtpVerifyRequestCWProxy get copyWith => _$OtpVerifyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpVerifyRequest _$OtpVerifyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OtpVerifyRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['phone', 'otp', 'app', 'terms_version'],
      );
      final val = OtpVerifyRequest(
        phone: $checkedConvert('phone', (v) => v as String),
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

Map<String, dynamic> _$OtpVerifyRequestToJson(OtpVerifyRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
      'otp': instance.otp,
      'app': _$AppEnumEnumMap[instance.app]!,
      'terms_version': instance.termsVersion,
    };

const _$AppEnumEnumMap = {
  AppEnum.customer: 'customer',
  AppEnum.rider: 'rider',
  AppEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
