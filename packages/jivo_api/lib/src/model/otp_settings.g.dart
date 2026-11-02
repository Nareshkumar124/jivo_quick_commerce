// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_settings.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OtpSettingsCWProxy {
  OtpSettings length(int length);

  OtpSettings resendAfterSeconds(int resendAfterSeconds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSettings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSettings(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSettings call({int length, int resendAfterSeconds});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOtpSettings.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOtpSettings.copyWith.fieldName(...)`
class _$OtpSettingsCWProxyImpl implements _$OtpSettingsCWProxy {
  const _$OtpSettingsCWProxyImpl(this._value);

  final OtpSettings _value;

  @override
  OtpSettings length(int length) => this(length: length);

  @override
  OtpSettings resendAfterSeconds(int resendAfterSeconds) =>
      this(resendAfterSeconds: resendAfterSeconds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OtpSettings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OtpSettings(...).copyWith(id: 12, name: "My name")
  /// ````
  OtpSettings call({
    Object? length = const $CopyWithPlaceholder(),
    Object? resendAfterSeconds = const $CopyWithPlaceholder(),
  }) {
    return OtpSettings(
      length: length == const $CopyWithPlaceholder()
          ? _value.length
          // ignore: cast_nullable_to_non_nullable
          : length as int,
      resendAfterSeconds: resendAfterSeconds == const $CopyWithPlaceholder()
          ? _value.resendAfterSeconds
          // ignore: cast_nullable_to_non_nullable
          : resendAfterSeconds as int,
    );
  }
}

extension $OtpSettingsCopyWith on OtpSettings {
  /// Returns a callable class that can be used as follows: `instanceOfOtpSettings.copyWith(...)` or like so:`instanceOfOtpSettings.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OtpSettingsCWProxy get copyWith => _$OtpSettingsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpSettings _$OtpSettingsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OtpSettings', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['length', 'resend_after_seconds']);
      final val = OtpSettings(
        length: $checkedConvert('length', (v) => (v as num).toInt()),
        resendAfterSeconds: $checkedConvert(
          'resend_after_seconds',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'resendAfterSeconds': 'resend_after_seconds'});

Map<String, dynamic> _$OtpSettingsToJson(OtpSettings instance) =>
    <String, dynamic>{
      'length': instance.length,
      'resend_after_seconds': instance.resendAfterSeconds,
    };
