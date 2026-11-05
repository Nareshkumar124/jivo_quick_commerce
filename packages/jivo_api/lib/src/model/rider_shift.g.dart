// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_shift.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderShiftCWProxy {
  RiderShift id(int id);

  RiderShift startedAt(DateTime startedAt);

  RiderShift endedAt(DateTime? endedAt);

  RiderShift endReason(ShiftEndReasonEnum? endReason);

  RiderShift endedBy(ShiftEndedByEnum? endedBy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderShift(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderShift(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderShift call({
    int id,
    DateTime startedAt,
    DateTime? endedAt,
    ShiftEndReasonEnum? endReason,
    ShiftEndedByEnum? endedBy,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderShift.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderShift.copyWith.fieldName(...)`
class _$RiderShiftCWProxyImpl implements _$RiderShiftCWProxy {
  const _$RiderShiftCWProxyImpl(this._value);

  final RiderShift _value;

  @override
  RiderShift id(int id) => this(id: id);

  @override
  RiderShift startedAt(DateTime startedAt) => this(startedAt: startedAt);

  @override
  RiderShift endedAt(DateTime? endedAt) => this(endedAt: endedAt);

  @override
  RiderShift endReason(ShiftEndReasonEnum? endReason) =>
      this(endReason: endReason);

  @override
  RiderShift endedBy(ShiftEndedByEnum? endedBy) => this(endedBy: endedBy);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderShift(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderShift(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderShift call({
    Object? id = const $CopyWithPlaceholder(),
    Object? startedAt = const $CopyWithPlaceholder(),
    Object? endedAt = const $CopyWithPlaceholder(),
    Object? endReason = const $CopyWithPlaceholder(),
    Object? endedBy = const $CopyWithPlaceholder(),
  }) {
    return RiderShift(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      startedAt: startedAt == const $CopyWithPlaceholder()
          ? _value.startedAt
          // ignore: cast_nullable_to_non_nullable
          : startedAt as DateTime,
      endedAt: endedAt == const $CopyWithPlaceholder()
          ? _value.endedAt
          // ignore: cast_nullable_to_non_nullable
          : endedAt as DateTime?,
      endReason: endReason == const $CopyWithPlaceholder()
          ? _value.endReason
          // ignore: cast_nullable_to_non_nullable
          : endReason as ShiftEndReasonEnum?,
      endedBy: endedBy == const $CopyWithPlaceholder()
          ? _value.endedBy
          // ignore: cast_nullable_to_non_nullable
          : endedBy as ShiftEndedByEnum?,
    );
  }
}

extension $RiderShiftCopyWith on RiderShift {
  /// Returns a callable class that can be used as follows: `instanceOfRiderShift.copyWith(...)` or like so:`instanceOfRiderShift.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderShiftCWProxy get copyWith => _$RiderShiftCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderShift _$RiderShiftFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RiderShift',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'started_at',
        'ended_at',
        'end_reason',
        'ended_by',
      ],
    );
    final val = RiderShift(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      startedAt: $checkedConvert(
        'started_at',
        (v) => DateTime.parse(v as String),
      ),
      endedAt: $checkedConvert(
        'ended_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      endReason: $checkedConvert(
        'end_reason',
        (v) => $enumDecodeNullable(
          _$ShiftEndReasonEnumEnumMap,
          v,
          unknownValue: ShiftEndReasonEnum.unknownDefaultOpenApi,
        ),
      ),
      endedBy: $checkedConvert(
        'ended_by',
        (v) => $enumDecodeNullable(
          _$ShiftEndedByEnumEnumMap,
          v,
          unknownValue: ShiftEndedByEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'startedAt': 'started_at',
    'endedAt': 'ended_at',
    'endReason': 'end_reason',
    'endedBy': 'ended_by',
  },
);

Map<String, dynamic> _$RiderShiftToJson(RiderShift instance) =>
    <String, dynamic>{
      'id': instance.id,
      'started_at': instance.startedAt.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
      'end_reason': _$ShiftEndReasonEnumEnumMap[instance.endReason],
      'ended_by': _$ShiftEndedByEnumEnumMap[instance.endedBy],
    };

const _$ShiftEndReasonEnumEnumMap = {
  ShiftEndReasonEnum.MANUAL: 'MANUAL',
  ShiftEndReasonEnum.AUTO_OFFLINE: 'AUTO_OFFLINE',
  ShiftEndReasonEnum.ADMIN: 'ADMIN',
  ShiftEndReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$ShiftEndedByEnumEnumMap = {
  ShiftEndedByEnum.rider: 'rider',
  ShiftEndedByEnum.system: 'system',
  ShiftEndedByEnum.ops: 'ops',
  ShiftEndedByEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
