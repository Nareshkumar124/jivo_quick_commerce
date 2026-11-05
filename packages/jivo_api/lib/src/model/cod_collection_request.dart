// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cod_mode_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cod_collection_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CodCollectionRequest {
  /// Returns a new [CodCollectionRequest] instance.
  CodCollectionRequest({required this.mode, required this.amount});

  @JsonKey(
    name: r'mode',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CodModeEnum.unknownDefaultOpenApi,
  )
  final CodModeEnum mode;

  /// Must equal `cod_amount_due` exactly.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodCollectionRequest &&
          other.mode == mode &&
          other.amount == amount;

  @override
  int get hashCode => mode.hashCode + amount.hashCode;

  factory CodCollectionRequest.fromJson(Map<String, dynamic> json) =>
      _$CodCollectionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CodCollectionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
