// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cod_qr_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cod_qr.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CodQr {
  /// Returns a new [CodQr] instance.
  CodQr({
    required this.qrId,

    required this.imageUrl,

    required this.amount,

    required this.status,

    required this.expiresAt,
  });

  @JsonKey(name: r'qr_id', required: true, includeIfNull: false)
  final String qrId;

  /// https PNG of the QR code.
  @JsonKey(name: r'image_url', required: true, includeIfNull: false)
  final String imageUrl;

  /// Exactly the amount due.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CodQrStatusEnum.unknownDefaultOpenApi,
  )
  final CodQrStatusEnum status;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodQr &&
          other.qrId == qrId &&
          other.imageUrl == imageUrl &&
          other.amount == amount &&
          other.status == status &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      qrId.hashCode +
      imageUrl.hashCode +
      amount.hashCode +
      status.hashCode +
      expiresAt.hashCode;

  factory CodQr.fromJson(Map<String, dynamic> json) => _$CodQrFromJson(json);

  Map<String, dynamic> toJson() => _$CodQrToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
