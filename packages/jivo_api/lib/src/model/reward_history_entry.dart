// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/reward_history_kind_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reward_history_entry.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RewardHistoryEntry {
  /// Returns a new [RewardHistoryEntry] instance.
  RewardHistoryEntry({
    required this.at,

    required this.kind,

    required this.title,

    required this.quantity,

    required this.orderNumber,
  });

  /// When it happened (UTC).
  @JsonKey(name: r'at', required: true, includeIfNull: false)
  final DateTime at;

  /// EARNED: a reward was given. CLAIMED: put on an order. USED: that order was delivered. EXPIRED: it ran out unused. VOLUME_FREE: free cartons of the volume offer with a delivered order.  * `EARNED` - Reward earned * `CLAIMED` - Reward put on an order * `USED` - Reward used (order delivered) * `EXPIRED` - Reward expired * `VOLUME_FREE` - Free cartons with a delivered order (volume offer)
  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RewardHistoryKindEnum.unknownDefaultOpenApi,
  )
  final RewardHistoryKindEnum kind;

  /// Display text, e.g. \"Welcome reward\".
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// Free cartons (1 for a reward).
  // minimum: 1
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  /// The order concerned; null for EARNED and EXPIRED.
  @JsonKey(name: r'order_number', required: true, includeIfNull: true)
  final String? orderNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardHistoryEntry &&
          other.at == at &&
          other.kind == kind &&
          other.title == title &&
          other.quantity == quantity &&
          other.orderNumber == orderNumber;

  @override
  int get hashCode =>
      at.hashCode +
      kind.hashCode +
      title.hashCode +
      quantity.hashCode +
      (orderNumber == null ? 0 : orderNumber.hashCode);

  factory RewardHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$RewardHistoryEntryFromJson(json);

  Map<String, dynamic> toJson() => _$RewardHistoryEntryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
