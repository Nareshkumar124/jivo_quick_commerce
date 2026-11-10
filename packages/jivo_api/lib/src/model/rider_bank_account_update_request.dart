// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_bank_account_update_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderBankAccountUpdateRequest {
  /// Returns a new [RiderBankAccountUpdateRequest] instance.
  RiderBankAccountUpdateRequest({
    required this.holderName,

    required this.accountNumber,

    required this.ifsc,

    this.upiId,
  });

  /// As on the bank account.
  @JsonKey(name: r'holder_name', required: true, includeIfNull: false)
  final String holderName;

  /// 9 to 18 digits. Stored encrypted; only the last 4 are shown.
  @JsonKey(name: r'account_number', required: true, includeIfNull: false)
  final String accountNumber;

  /// e.g. HDFC0001234.
  @JsonKey(name: r'ifsc', required: true, includeIfNull: false)
  final String ifsc;

  /// Optional, e.g. name@okhdfcbank. Send null or \"\" to remove.
  @JsonKey(name: r'upi_id', required: false, includeIfNull: false)
  final String? upiId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderBankAccountUpdateRequest &&
          other.holderName == holderName &&
          other.accountNumber == accountNumber &&
          other.ifsc == ifsc &&
          other.upiId == upiId;

  @override
  int get hashCode =>
      holderName.hashCode +
      accountNumber.hashCode +
      ifsc.hashCode +
      (upiId == null ? 0 : upiId.hashCode);

  factory RiderBankAccountUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$RiderBankAccountUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RiderBankAccountUpdateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
