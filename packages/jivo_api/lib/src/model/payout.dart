// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/date_only.dart';
import 'package:jivo_api/src/model/payout_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payout.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Payout {
  /// Returns a new [Payout] instance.
  Payout({
    required this.id,

    required this.periodStart,

    required this.periodEnd,

    required this.amount,

    required this.status,

    required this.reference,

    required this.paidAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// IST calendar date, YYYY-MM-DD.
  @JsonKey(
    name: r'period_start',
    toJson: jivoDateToJson,
    required: true,
    includeIfNull: false,
  )
  final DateTime periodStart;

  /// IST calendar date, YYYY-MM-DD. Inclusive.
  @JsonKey(
    name: r'period_end',
    toJson: jivoDateToJson,
    required: true,
    includeIfNull: false,
  )
  final DateTime periodEnd;

  /// Paid or to be paid.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PayoutStatusEnum.unknownDefaultOpenApi,
  )
  final PayoutStatusEnum status;

  /// Bank transfer reference (UTR).
  @JsonKey(name: r'reference', required: true, includeIfNull: true)
  final String? reference;

  /// UTC instant; null if PENDING.
  @JsonKey(name: r'paid_at', required: true, includeIfNull: true)
  final DateTime? paidAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payout &&
          other.id == id &&
          other.periodStart == periodStart &&
          other.periodEnd == periodEnd &&
          other.amount == amount &&
          other.status == status &&
          other.reference == reference &&
          other.paidAt == paidAt;

  @override
  int get hashCode =>
      id.hashCode +
      periodStart.hashCode +
      periodEnd.hashCode +
      amount.hashCode +
      status.hashCode +
      (reference == null ? 0 : reference.hashCode) +
      (paidAt == null ? 0 : paidAt.hashCode);

  factory Payout.fromJson(Map<String, dynamic> json) => _$PayoutFromJson(json);

  Map<String, dynamic> toJson() => _$PayoutToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
