// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_otp_send_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EmailOtpSendRequestCWProxy {
  EmailOtpSendRequest email(String email);

  EmailOtpSendRequest app(AppEnum app);

  EmailOtpSendRequest purpose(OtpPurposeEnum? purpose);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpSendRequest call({
    String email,
    AppEnum app,
    OtpPurposeEnum? purpose,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEmailOtpSendRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEmailOtpSendRequest.copyWith.fieldName(...)`
class _$EmailOtpSendRequestCWProxyImpl implements _$EmailOtpSendRequestCWProxy {
  const _$EmailOtpSendRequestCWProxyImpl(this._value);

  final EmailOtpSendRequest _value;

  @override
  EmailOtpSendRequest email(String email) => this(email: email);

  @override
  EmailOtpSendRequest app(AppEnum app) => this(app: app);

  @override
  EmailOtpSendRequest purpose(OtpPurposeEnum? purpose) =>
      this(purpose: purpose);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EmailOtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EmailOtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  EmailOtpSendRequest call({
    Object? email = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? purpose = const $CopyWithPlaceholder(),
  }) {
    return EmailOtpSendRequest(
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
      app: app == const $CopyWithPlaceholder()
          ? _value.app
          // ignore: cast_nullable_to_non_nullable
          : app as AppEnum,
      purpose: purpose == const $CopyWithPlaceholder()
          ? _value.purpose
          // ignore: cast_nullable_to_non_nullable
          : purpose as OtpPurposeEnum?,
    );
  }
}

extension $EmailOtpSendRequestCopyWith on EmailOtpSendRequest {
  /// Returns a callable class that can be used as follows: `instanceOfEmailOtpSendRequest.copyWith(...)` or like so:`instanceOfEmailOtpSendRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EmailOtpSendRequestCWProxy get copyWith =>
      _$EmailOtpSendRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EmailOtpSendRequest _$EmailOtpSendRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EmailOtpSendRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['email', 'app']);
      final val = EmailOtpSendRequest(
        email: $checkedConvert('email', (v) => v as String),
        app: $checkedConvert(
          'app',
          (v) => $enumDecode(
            _$AppEnumEnumMap,
            v,
            unknownValue: AppEnum.unknownDefaultOpenApi,
          ),
        ),
        purpose: $checkedConvert(
          'purpose',
          (v) =>
              $enumDecodeNullable(
                _$OtpPurposeEnumEnumMap,
                v,
                unknownValue: OtpPurposeEnum.unknownDefaultOpenApi,
              ) ??
              OtpPurposeEnum.login,
        ),
      );
      return val;
    });

Map<String, dynamic> _$EmailOtpSendRequestToJson(
  EmailOtpSendRequest instance,
) => <String, dynamic>{
  'email': instance.email,
  'app': _$AppEnumEnumMap[instance.app]!,
  'purpose': ?_$OtpPurposeEnumEnumMap[instance.purpose],
};

const _$AppEnumEnumMap = {
  AppEnum.customer: 'customer',
  AppEnum.rider: 'rider',
  AppEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$OtpPurposeEnumEnumMap = {
  OtpPurposeEnum.login: 'login',
  OtpPurposeEnum.deleteAccount: 'delete_account',
  OtpPurposeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
