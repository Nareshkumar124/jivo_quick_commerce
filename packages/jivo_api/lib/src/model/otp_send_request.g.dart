// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_send_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OtpSendRequestCWProxy {
  OtpSendRequest phone(String phone);

  OtpSendRequest app(AppEnum app);

  OtpSendRequest purpose(OtpPurposeEnum? purpose);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSendRequest call({String phone, AppEnum app, OtpPurposeEnum? purpose});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOtpSendRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOtpSendRequest.copyWith.fieldName(...)`
class _$OtpSendRequestCWProxyImpl implements _$OtpSendRequestCWProxy {
  const _$OtpSendRequestCWProxyImpl(this._value);

  final OtpSendRequest _value;

  @override
  OtpSendRequest phone(String phone) => this(phone: phone);

  @override
  OtpSendRequest app(AppEnum app) => this(app: app);

  @override
  OtpSendRequest purpose(OtpPurposeEnum? purpose) => this(purpose: purpose);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSendRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSendRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSendRequest call({
    Object? phone = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? purpose = const $CopyWithPlaceholder(),
  }) {
    return OtpSendRequest(
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
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

extension $OtpSendRequestCopyWith on OtpSendRequest {
  /// Returns a callable class that can be used as follows: `instanceOfOtpSendRequest.copyWith(...)` or like so:`instanceOfOtpSendRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OtpSendRequestCWProxy get copyWith => _$OtpSendRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpSendRequest _$OtpSendRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OtpSendRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['phone', 'app']);
      final val = OtpSendRequest(
        phone: $checkedConvert('phone', (v) => v as String),
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

Map<String, dynamic> _$OtpSendRequestToJson(OtpSendRequest instance) =>
    <String, dynamic>{
      'phone': instance.phone,
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
