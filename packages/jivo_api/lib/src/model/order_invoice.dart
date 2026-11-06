// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_invoice.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderInvoice {
  /// Returns a new [OrderInvoice] instance.
  OrderInvoice({
    required this.invoiceNumber,

    required this.issuedAt,

    required this.url,

    required this.expiresAt,
  });

  /// e.g. \"GGN01/26-27/000123\".
  @JsonKey(name: r'invoice_number', required: true, includeIfNull: false)
  final String invoiceNumber;

  @JsonKey(name: r'issued_at', required: true, includeIfNull: false)
  final DateTime issuedAt;

  /// Signed link to the PDF; open or download it before `expires_at`.
  @JsonKey(name: r'url', required: true, includeIfNull: false)
  final String url;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderInvoice &&
          other.invoiceNumber == invoiceNumber &&
          other.issuedAt == issuedAt &&
          other.url == url &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      invoiceNumber.hashCode +
      issuedAt.hashCode +
      url.hashCode +
      expiresAt.hashCode;

  factory OrderInvoice.fromJson(Map<String, dynamic> json) =>
      _$OrderInvoiceFromJson(json);

  Map<String, dynamic> toJson() => _$OrderInvoiceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
