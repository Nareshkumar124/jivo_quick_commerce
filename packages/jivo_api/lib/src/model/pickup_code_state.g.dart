// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pickup_code_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PickupCodeStateCWProxy {
  PickupCodeState attemptsRemaining(int attemptsRemaining);

  PickupCodeState locked(bool locked);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PickupCodeState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PickupCodeState(...).copyWith(id: 12, name: "My name")
  /// ````
  PickupCodeState call({int attemptsRemaining, bool locked});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPickupCodeState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPickupCodeState.copyWith.fieldName(...)`
class _$PickupCodeStateCWProxyImpl implements _$PickupCodeStateCWProxy {
  const _$PickupCodeStateCWProxyImpl(this._value);

  final PickupCodeState _value;

  @override
  PickupCodeState attemptsRemaining(int attemptsRemaining) =>
      this(attemptsRemaining: attemptsRemaining);

  @override
  PickupCodeState locked(bool locked) => this(locked: locked);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PickupCodeState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PickupCodeState(...).copyWith(id: 12, name: "My name")
  /// ````
  PickupCodeState call({
    Object? attemptsRemaining = const $CopyWithPlaceholder(),
    Object? locked = const $CopyWithPlaceholder(),
  }) {
    return PickupCodeState(
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

extension $PickupCodeStateCopyWith on PickupCodeState {
  /// Returns a callable class that can be used as follows: `instanceOfPickupCodeState.copyWith(...)` or like so:`instanceOfPickupCodeState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PickupCodeStateCWProxy get copyWith => _$PickupCodeStateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PickupCodeState _$PickupCodeStateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PickupCodeState', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['attempts_remaining', 'locked']);
      final val = PickupCodeState(
        attemptsRemaining: $checkedConvert(
          'attempts_remaining',
          (v) => (v as num).toInt(),
        ),
        locked: $checkedConvert('locked', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'attemptsRemaining': 'attempts_remaining'});

Map<String, dynamic> _$PickupCodeStateToJson(PickupCodeState instance) =>
    <String, dynamic>{
      'attempts_remaining': instance.attemptsRemaining,
      'locked': instance.locked,
    };
