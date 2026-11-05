// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cash_entry_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cash_ledger_entry.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CashLedgerEntry {
  /// Returns a new [CashLedgerEntry] instance.
  CashLedgerEntry({
    required this.id,

    required this.entryType,

    required this.amount,

    required this.balanceAfter,

    required this.orderNumber,

    required this.note,

    required this.recordedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(
    name: r'entry_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CashEntryTypeEnum.unknownDefaultOpenApi,
  )
  final CashEntryTypeEnum entryType;

  /// Signed: + collected, - deposited (\"-1500.00\").
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  /// Cash in hand after this entry.
  @JsonKey(name: r'balance_after', required: true, includeIfNull: false)
  final String balanceAfter;

  @JsonKey(name: r'order_number', required: true, includeIfNull: true)
  final String? orderNumber;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashLedgerEntry &&
          other.id == id &&
          other.entryType == entryType &&
          other.amount == amount &&
          other.balanceAfter == balanceAfter &&
          other.orderNumber == orderNumber &&
          other.note == note &&
          other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      id.hashCode +
      entryType.hashCode +
      amount.hashCode +
      balanceAfter.hashCode +
      (orderNumber == null ? 0 : orderNumber.hashCode) +
      note.hashCode +
      recordedAt.hashCode;

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$CashLedgerEntryFromJson(json);

  Map<String, dynamic> toJson() => _$CashLedgerEntryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
