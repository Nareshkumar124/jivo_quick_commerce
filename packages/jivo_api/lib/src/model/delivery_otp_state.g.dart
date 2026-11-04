// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_otp_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeliveryOtpStateCWProxy {
  DeliveryOtpState length(int length);

  DeliveryOtpState attemptsRemaining(int attemptsRemaining);

  DeliveryOtpState locked(bool locked);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryOtpState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryOtpState(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryOtpState call({int length, int attemptsRemaining, bool locked});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeliveryOtpState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeliveryOtpState.copyWith.fieldName(...)`
class _$DeliveryOtpStateCWProxyImpl implements _$DeliveryOtpStateCWProxy {
  const _$DeliveryOtpStateCWProxyImpl(this._value);

  final DeliveryOtpState _value;

  @override
  DeliveryOtpState length(int length) => this(length: length);

  @override
  DeliveryOtpState attemptsRemaining(int attemptsRemaining) =>
      this(attemptsRemaining: attemptsRemaining);

  @override
  DeliveryOtpState locked(bool locked) => this(locked: locked);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryOtpState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryOtpState(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryOtpState call({
    Object? length = const $CopyWithPlaceholder(),
    Object? attemptsRemaining = const $CopyWithPlaceholder(),
    Object? locked = const $CopyWithPlaceholder(),
  }) {
    return DeliveryOtpState(
      length: length == const $CopyWithPlaceholder()
          ? _value.length
          // ignore: cast_nullable_to_non_nullable
          : length as int,
      attemptsRemaining: attemptsRemaining == const $CopyWithPlaceholder()
          ? _value.attemptsRemaining
          // ignore: cast_nullable_to_non_nullable
          : attemptsRemaining as int,
      locked: locked == const $CopyWithPlaceholder()
          ? _value.locked
          // ignore: cast_nullable_to_non_nullable
          : locked as bool,
    );
  }
}

extension $DeliveryOtpStateCopyWith on DeliveryOtpState {
  /// Returns a callable class that can be used as follows: `instanceOfDeliveryOtpState.copyWith(...)` or like so:`instanceOfDeliveryOtpState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeliveryOtpStateCWProxy get copyWith => _$DeliveryOtpStateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryOtpState _$DeliveryOtpStateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DeliveryOtpState', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['length', 'attempts_remaining', 'locked'],
      );
      final val = DeliveryOtpState(
        length: $checkedConvert('length', (v) => (v as num).toInt()),
        attemptsRemaining: $checkedConvert(
          'attempts_remaining',
          (v) => (v as num).toInt(),
        ),
        locked: $checkedConvert('locked', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'attemptsRemaining': 'attempts_remaining'});

Map<String, dynamic> _$DeliveryOtpStateToJson(DeliveryOtpState instance) =>
    <String, dynamic>{
      'length': instance.length,
      'attempts_remaining': instance.attemptsRemaining,
      'locked': instance.locked,
    };
