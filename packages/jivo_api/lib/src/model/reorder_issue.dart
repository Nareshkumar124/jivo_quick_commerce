// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/reorder_issue_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reorder_issue.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReorderIssue {
  /// Returns a new [ReorderIssue] instance.
  ReorderIssue({
    required this.variantId,

    required this.productName,

    required this.variantName,

    required this.requestedQuantity,

    required this.addedQuantity,

    required this.reason,
  });

  @JsonKey(name: r'variant_id', required: true, includeIfNull: false)
  final int variantId;

  @JsonKey(name: r'product_name', required: true, includeIfNull: false)
  final String productName;

  @JsonKey(name: r'variant_name', required: true, includeIfNull: false)
  final String variantName;

  /// Units in the past order (those that were delivered or coming).
  // minimum: 1
  @JsonKey(name: r'requested_quantity', required: true, includeIfNull: false)
  final int requestedQuantity;

  /// Units now in the cart for this variant (0 = not added).
  // minimum: 0
  @JsonKey(name: r'added_quantity', required: true, includeIfNull: false)
  final int addedQuantity;

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ReorderIssueReasonEnum.unknownDefaultOpenApi,
  )
  final ReorderIssueReasonEnum reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReorderIssue &&
          other.variantId == variantId &&
          other.productName == productName &&
          other.variantName == variantName &&
          other.requestedQuantity == requestedQuantity &&
          other.addedQuantity == addedQuantity &&
          other.reason == reason;

  @override
  int get hashCode =>
      variantId.hashCode +
      productName.hashCode +
      variantName.hashCode +
      requestedQuantity.hashCode +
      addedQuantity.hashCode +
      reason.hashCode;

  factory ReorderIssue.fromJson(Map<String, dynamic> json) =>
      _$ReorderIssueFromJson(json);

  Map<String, dynamic> toJson() => _$ReorderIssueToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
