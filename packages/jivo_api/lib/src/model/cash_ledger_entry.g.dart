// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cash_ledger_entry.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CashLedgerEntryCWProxy {
  CashLedgerEntry id(int id);

  CashLedgerEntry entryType(CashEntryTypeEnum entryType);

  CashLedgerEntry amount(String amount);

  CashLedgerEntry balanceAfter(String balanceAfter);

  CashLedgerEntry orderNumber(String? orderNumber);

  CashLedgerEntry note(String note);

  CashLedgerEntry recordedAt(DateTime recordedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CashLedgerEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CashLedgerEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  CashLedgerEntry call({
    int id,
    CashEntryTypeEnum entryType,
    String amount,
    String balanceAfter,
    String? orderNumber,
    String note,
    DateTime recordedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCashLedgerEntry.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCashLedgerEntry.copyWith.fieldName(...)`
class _$CashLedgerEntryCWProxyImpl implements _$CashLedgerEntryCWProxy {
  const _$CashLedgerEntryCWProxyImpl(this._value);

  final CashLedgerEntry _value;

  @override
  CashLedgerEntry id(int id) => this(id: id);

  @override
  CashLedgerEntry entryType(CashEntryTypeEnum entryType) =>
      this(entryType: entryType);

  @override
  CashLedgerEntry amount(String amount) => this(amount: amount);

  @override
  CashLedgerEntry balanceAfter(String balanceAfter) =>
      this(balanceAfter: balanceAfter);

  @override
  CashLedgerEntry orderNumber(String? orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  CashLedgerEntry note(String note) => this(note: note);

  @override
  CashLedgerEntry recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CashLedgerEntry(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CashLedgerEntry(...).copyWith(id: 12, name: "My name")
  /// ````
  CashLedgerEntry call({
    Object? id = const $CopyWithPlaceholder(),
    Object? entryType = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? balanceAfter = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
  }) {
    return CashLedgerEntry(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      entryType: entryType == const $CopyWithPlaceholder()
          ? _value.entryType
          // ignore: cast_nullable_to_non_nullable
          : entryType as CashEntryTypeEnum,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      balanceAfter: balanceAfter == const $CopyWithPlaceholder()
          ? _value.balanceAfter
          // ignore: cast_nullable_to_non_nullable
          : balanceAfter as String,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String?,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
      recordedAt: recordedAt == const $CopyWithPlaceholder()
          ? _value.recordedAt
          // ignore: cast_nullable_to_non_nullable
          : recordedAt as DateTime,
    );
  }
}

extension $CashLedgerEntryCopyWith on CashLedgerEntry {
  /// Returns a callable class that can be used as follows: `instanceOfCashLedgerEntry.copyWith(...)` or like so:`instanceOfCashLedgerEntry.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CashLedgerEntryCWProxy get copyWith => _$CashLedgerEntryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CashLedgerEntry _$CashLedgerEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CashLedgerEntry',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'entry_type',
            'amount',
            'balance_after',
            'order_number',
            'note',
            'recorded_at',
          ],
        );
        final val = CashLedgerEntry(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          entryType: $checkedConvert(
            'entry_type',
            (v) => $enumDecode(
              _$CashEntryTypeEnumEnumMap,
              v,
              unknownValue: CashEntryTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          amount: $checkedConvert('amount', (v) => v as String),
          balanceAfter: $checkedConvert('balance_after', (v) => v as String),
          orderNumber: $checkedConvert('order_number', (v) => v as String?),
          note: $checkedConvert('note', (v) => v as String),
          recordedAt: $checkedConvert(
            'recorded_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'entryType': 'entry_type',
        'balanceAfter': 'balance_after',
        'orderNumber': 'order_number',
        'recordedAt': 'recorded_at',
      },
    );

Map<String, dynamic> _$CashLedgerEntryToJson(CashLedgerEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'entry_type': _$CashEntryTypeEnumEnumMap[instance.entryType]!,
      'amount': instance.amount,
      'balance_after': instance.balanceAfter,
      'order_number': instance.orderNumber,
      'note': instance.note,
      'recorded_at': instance.recordedAt.toIso8601String(),
    };

const _$CashEntryTypeEnumEnumMap = {
  CashEntryTypeEnum.COD_COLLECTED: 'COD_COLLECTED',
  CashEntryTypeEnum.DEPOSIT: 'DEPOSIT',
  CashEntryTypeEnum.ADJUSTMENT: 'ADJUSTMENT',
  CashEntryTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
