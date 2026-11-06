// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cod_collection_request.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'deliver_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeliverRequest {
  /// Returns a new [DeliverRequest] instance.
  DeliverRequest({required this.otp, this.cod});

  /// The 4-digit delivery OTP the customer reads out.
  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final String otp;

  /// Required for COD orders, absent for prepaid.
  @JsonKey(name: r'cod', required: false, includeIfNull: false)
  final CodCollectionRequest? cod;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliverRequest && other.otp == otp && other.cod == cod;

  @override
  int get hashCode => otp.hashCode + (cod == null ? 0 : cod.hashCode);

  factory DeliverRequest.fromJson(Map<String, dynamic> json) =>
      _$DeliverRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DeliverRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
