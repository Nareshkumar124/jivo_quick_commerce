// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unit_price.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UnitPrice {
  /// Returns a new [UnitPrice] instance.
  UnitPrice({required this.amount, required this.per});

  /// Selling price per `per`.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  /// The unit quantity, e.g. \"100 ml\", \"100 g\", \"1 kg\".
  @JsonKey(name: r'per', required: true, includeIfNull: false)
  final String per;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitPrice && other.amount == amount && other.per == per;

  @override
  int get hashCode => amount.hashCode + per.hashCode;

  factory UnitPrice.fromJson(Map<String, dynamic> json) =>
      _$UnitPriceFromJson(json);

  Map<String, dynamic> toJson() => _$UnitPriceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
