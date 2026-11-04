// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/reorder_issue.dart';
import 'package:jivo_api/src/model/cart.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reorder_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReorderResult {
  /// Returns a new [ReorderResult] instance.
  ReorderResult({required this.cart, required this.unavailable});

  /// The whole cart after the items were added.
  @JsonKey(name: r'cart', required: true, includeIfNull: false)
  final Cart cart;

  /// Lines that could not be added in full; [] when everything was added.
  @JsonKey(name: r'unavailable', required: true, includeIfNull: false)
  final List<ReorderIssue> unavailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReorderResult &&
          other.cart == cart &&
          other.unavailable == unavailable;

  @override
  int get hashCode => cart.hashCode + unavailable.hashCode;

  factory ReorderResult.fromJson(Map<String, dynamic> json) =>
      _$ReorderResultFromJson(json);

  Map<String, dynamic> toJson() => _$ReorderResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
