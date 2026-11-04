// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'paginated_order_summary_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaginatedOrderSummaryList {
  /// Returns a new [PaginatedOrderSummaryList] instance.
  PaginatedOrderSummaryList({
    required this.count,

    required this.next,

    required this.previous,

    required this.results,
  });

  @JsonKey(name: r'count', required: true, includeIfNull: false)
  final int count;

  @JsonKey(name: r'next', required: true, includeIfNull: true)
  final String? next;

  @JsonKey(name: r'previous', required: true, includeIfNull: true)
  final String? previous;

  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<OrderSummary> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedOrderSummaryList &&
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

  factory PaginatedOrderSummaryList.fromJson(Map<String, dynamic> json) =>
      _$PaginatedOrderSummaryListFromJson(json);

  Map<String, dynamic> toJson() => _$PaginatedOrderSummaryListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
