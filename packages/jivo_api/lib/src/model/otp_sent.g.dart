// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_sent.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OtpSentCWProxy {
  OtpSent otpLength(int otpLength);

  OtpSent expiresInSeconds(int expiresInSeconds);

  OtpSent resendAfterSeconds(int resendAfterSeconds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSent(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSent call({int otpLength, int expiresInSeconds, int resendAfterSeconds});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOtpSent.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOtpSent.copyWith.fieldName(...)`
class _$OtpSentCWProxyImpl implements _$OtpSentCWProxy {
  const _$OtpSentCWProxyImpl(this._value);

  final OtpSent _value;

  @override
  OtpSent otpLength(int otpLength) => this(otpLength: otpLength);

  @override
  OtpSent expiresInSeconds(int expiresInSeconds) =>
      this(expiresInSeconds: expiresInSeconds);

  @override
  OtpSent resendAfterSeconds(int resendAfterSeconds) =>
      this(resendAfterSeconds: resendAfterSeconds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSent(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSent call({
    Object? otpLength = const $CopyWithPlaceholder(),
    Object? expiresInSeconds = const $CopyWithPlaceholder(),
    Object? resendAfterSeconds = const $CopyWithPlaceholder(),
  }) {
    return OtpSent(
      otpLength: otpLength == const $CopyWithPlaceholder()
          ? _value.otpLength
          // ignore: cast_nullable_to_non_nullable
          : otpLength as int,
      expiresInSeconds: expiresInSeconds == const $CopyWithPlaceholder()
          ? _value.expiresInSeconds
          // ignore: cast_nullable_to_non_nullable
          : expiresInSeconds as int,
      resendAfterSeconds: resendAfterSeconds == const $CopyWithPlaceholder()
          ? _value.resendAfterSeconds
          // ignore: cast_nullable_to_non_nullable
          : resendAfterSeconds as int,
    );
  }
}

extension $OtpSentCopyWith on OtpSent {
  /// Returns a callable class that can be used as follows: `instanceOfOtpSent.copyWith(...)` or like so:`instanceOfOtpSent.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OtpSentCWProxy get copyWith => _$OtpSentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpSent _$OtpSentFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OtpSent',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'otp_length',
        'expires_in_seconds',
        'resend_after_seconds',
      ],
    );
    final val = OtpSent(
      otpLength: $checkedConvert('otp_length', (v) => (v as num).toInt()),
      expiresInSeconds: $checkedConvert(
        'expires_in_seconds',
        (v) => (v as num).toInt(),
      ),
      resendAfterSeconds: $checkedConvert(
        'resend_after_seconds',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'otpLength': 'otp_length',
    'expiresInSeconds': 'expires_in_seconds',
    'resendAfterSeconds': 'resend_after_seconds',
  },
);

Map<String, dynamic> _$OtpSentToJson(OtpSent instance) => <String, dynamic>{
  'otp_length': instance.otpLength,
  'expires_in_seconds': instance.expiresInSeconds,
  'resend_after_seconds': instance.resendAfterSeconds,
};
