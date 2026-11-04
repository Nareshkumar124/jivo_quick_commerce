// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PayoutCWProxy {
  Payout id(int id);

  Payout periodStart(DateTime periodStart);

  Payout periodEnd(DateTime periodEnd);

  Payout amount(String amount);

  Payout status(PayoutStatusEnum status);

  Payout reference(String? reference);

  Payout paidAt(DateTime? paidAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Payout(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Payout(...).copyWith(id: 12, name: "My name")
  /// ````
  Payout call({
    int id,
    DateTime periodStart,
    DateTime periodEnd,
    String amount,
    PayoutStatusEnum status,
    String? reference,
    DateTime? paidAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPayout.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPayout.copyWith.fieldName(...)`
class _$PayoutCWProxyImpl implements _$PayoutCWProxy {
  const _$PayoutCWProxyImpl(this._value);

  final Payout _value;

  @override
  Payout id(int id) => this(id: id);

  @override
  Payout periodStart(DateTime periodStart) => this(periodStart: periodStart);

  @override
  Payout periodEnd(DateTime periodEnd) => this(periodEnd: periodEnd);

  @override
  Payout amount(String amount) => this(amount: amount);

  @override
  Payout status(PayoutStatusEnum status) => this(status: status);

  @override
  Payout reference(String? reference) => this(reference: reference);

  @override
  Payout paidAt(DateTime? paidAt) => this(paidAt: paidAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Payout(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Payout(...).copyWith(id: 12, name: "My name")
  /// ````
  Payout call({
    Object? id = const $CopyWithPlaceholder(),
    Object? periodStart = const $CopyWithPlaceholder(),
    Object? periodEnd = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? reference = const $CopyWithPlaceholder(),
    Object? paidAt = const $CopyWithPlaceholder(),
  }) {
    return Payout(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      periodStart: periodStart == const $CopyWithPlaceholder()
          ? _value.periodStart
          // ignore: cast_nullable_to_non_nullable
          : periodStart as DateTime,
      periodEnd: periodEnd == const $CopyWithPlaceholder()
          ? _value.periodEnd
          // ignore: cast_nullable_to_non_nullable
          : periodEnd as DateTime,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PayoutStatusEnum,
      reference: reference == const $CopyWithPlaceholder()
          ? _value.reference
          // ignore: cast_nullable_to_non_nullable
          : reference as String?,
      paidAt: paidAt == const $CopyWithPlaceholder()
          ? _value.paidAt
          // ignore: cast_nullable_to_non_nullable
          : paidAt as DateTime?,
    );
  }
}

extension $PayoutCopyWith on Payout {
  /// Returns a callable class that can be used as follows: `instanceOfPayout.copyWith(...)` or like so:`instanceOfPayout.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PayoutCWProxy get copyWith => _$PayoutCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Payout _$PayoutFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Payout',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'period_start',
        'period_end',
        'amount',
        'status',
        'reference',
        'paid_at',
      ],
    );
    final val = Payout(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      periodStart: $checkedConvert(
        'period_start',
        (v) => DateTime.parse(v as String),
      ),
      periodEnd: $checkedConvert(
        'period_end',
        (v) => DateTime.parse(v as String),
      ),
      amount: $checkedConvert('amount', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$PayoutStatusEnumEnumMap,
          v,
          unknownValue: PayoutStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      reference: $checkedConvert('reference', (v) => v as String?),
      paidAt: $checkedConvert(
        'paid_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'periodStart': 'period_start',
    'periodEnd': 'period_end',
    'paidAt': 'paid_at',
  },
);

Map<String, dynamic> _$PayoutToJson(Payout instance) => <String, dynamic>{
  'id': instance.id,
  'period_start': instance.periodStart.toIso8601String(),
  'period_end': instance.periodEnd.toIso8601String(),
  'amount': instance.amount,
  'status': _$PayoutStatusEnumEnumMap[instance.status]!,
  'reference': instance.reference,
  'paid_at': instance.paidAt?.toIso8601String(),
};

const _$PayoutStatusEnumEnumMap = {
  PayoutStatusEnum.PENDING: 'PENDING',
  PayoutStatusEnum.PAID: 'PAID',
  PayoutStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
