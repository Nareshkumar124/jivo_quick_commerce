// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cash_ledger_entry.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_cash_ledger.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedCashLedger {
  /// Returns a new [PaginatedCashLedger] instance.
  PaginatedCashLedger({
    required this.count,

    required this.next,

    required this.previous,

    required this.results,
  });

  /// All entries, whatever `before_id`.
  @JsonKey(name: r'count', required: true, includeIfNull: false)
  final int count;

  /// Older entries (carries `before_id`).
  @JsonKey(name: r'next', required: true, includeIfNull: true)
  final String? next;

  /// Always null.
  @JsonKey(name: r'previous', required: true, includeIfNull: true)
  final String? previous;

  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<CashLedgerEntry> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedCashLedger &&
          other.count == count &&
          other.next == next &&
          other.previous == previous &&
          other.results == results;

  @override
  int get hashCode =>
      count.hashCode +
      (next == null ? 0 : next.hashCode) +
      (previous == null ? 0 : previous.hashCode) +
      results.hashCode;

  factory PaginatedCashLedger.fromJson(Map<String, dynamic> json) =>
      _$PaginatedCashLedgerFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedCashLedgerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
