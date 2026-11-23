// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_reject_reasons.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LocationRejectReasonsCWProxy {
  LocationRejectReasons tooOld(int tooOld);

  LocationRejectReasons future(int future);

  LocationRejectReasons invalidPoint(int invalidPoint);

  LocationRejectReasons implausibleJump(int implausibleJump);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationRejectReasons(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationRejectReasons(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationRejectReasons call({
    int tooOld,
    int future,
    int invalidPoint,
    int implausibleJump,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLocationRejectReasons.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLocationRejectReasons.copyWith.fieldName(...)`
class _$LocationRejectReasonsCWProxyImpl
    implements _$LocationRejectReasonsCWProxy {
  const _$LocationRejectReasonsCWProxyImpl(this._value);

  final LocationRejectReasons _value;

  @override
  LocationRejectReasons tooOld(int tooOld) => this(tooOld: tooOld);

  @override
  LocationRejectReasons future(int future) => this(future: future);

  @override
  LocationRejectReasons invalidPoint(int invalidPoint) =>
      this(invalidPoint: invalidPoint);

  @override
  LocationRejectReasons implausibleJump(int implausibleJump) =>
      this(implausibleJump: implausibleJump);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationRejectReasons(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationRejectReasons(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationRejectReasons call({
    Object? tooOld = const $CopyWithPlaceholder(),
    Object? future = const $CopyWithPlaceholder(),
    Object? invalidPoint = const $CopyWithPlaceholder(),
    Object? implausibleJump = const $CopyWithPlaceholder(),
  }) {
    return LocationRejectReasons(
      tooOld: tooOld == const $CopyWithPlaceholder()
          ? _value.tooOld
          // ignore: cast_nullable_to_non_nullable
          : tooOld as int,
      future: future == const $CopyWithPlaceholder()
          ? _value.future
          // ignore: cast_nullable_to_non_nullable
          : future as int,
      invalidPoint: invalidPoint == const $CopyWithPlaceholder()
          ? _value.invalidPoint
          // ignore: cast_nullable_to_non_nullable
          : invalidPoint as int,
      implausibleJump: implausibleJump == const $CopyWithPlaceholder()
          ? _value.implausibleJump
          // ignore: cast_nullable_to_non_nullable
          : implausibleJump as int,
    );
  }
}

extension $LocationRejectReasonsCopyWith on LocationRejectReasons {
  /// Returns a callable class that can be used as follows: `instanceOfLocationRejectReasons.copyWith(...)` or like so:`instanceOfLocationRejectReasons.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LocationRejectReasonsCWProxy get copyWith =>
      _$LocationRejectReasonsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationRejectReasons _$LocationRejectReasonsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'LocationRejectReasons',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'too_old',
        'future',
        'invalid_point',
        'implausible_jump',
      ],
    );
    final val = LocationRejectReasons(
      tooOld: $checkedConvert('too_old', (v) => (v as num).toInt()),
      future: $checkedConvert('future', (v) => (v as num).toInt()),
      invalidPoint: $checkedConvert('invalid_point', (v) => (v as num).toInt()),
      implausibleJump: $checkedConvert(
        'implausible_jump',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'tooOld': 'too_old',
    'invalidPoint': 'invalid_point',
    'implausibleJump': 'implausible_jump',
  },
);

Map<String, dynamic> _$LocationRejectReasonsToJson(
  LocationRejectReasons instance,
) => <String, dynamic>{
  'too_old': instance.tooOld,
  'future': instance.future,
  'invalid_point': instance.invalidPoint,
  'implausible_jump': instance.implausibleJump,
};
