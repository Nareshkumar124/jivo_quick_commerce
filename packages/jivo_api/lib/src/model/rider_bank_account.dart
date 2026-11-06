// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_bank_account.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderBankAccount {
  /// Returns a new [RiderBankAccount] instance.
  RiderBankAccount({
    required this.holderName,

    required this.accountNumberMasked,

    required this.ifsc,

    required this.upiId,

    required this.updatedAt,
  });

  @JsonKey(name: r'holder_name', required: true, includeIfNull: false)
  final String holderName;

  /// \"XXXXXX6789\".
  @JsonKey(name: r'account_number_masked', required: true, includeIfNull: false)
  final String accountNumberMasked;

  @JsonKey(name: r'ifsc', required: true, includeIfNull: false)
  final String ifsc;

  @JsonKey(name: r'upi_id', required: true, includeIfNull: true)
  final String? upiId;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderBankAccount &&
          other.holderName == holderName &&
          other.accountNumberMasked == accountNumberMasked &&
          other.ifsc == ifsc &&
          other.upiId == upiId &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      holderName.hashCode +
      accountNumberMasked.hashCode +
      ifsc.hashCode +
      (upiId == null ? 0 : upiId.hashCode) +
      updatedAt.hashCode;

  factory RiderBankAccount.fromJson(Map<String, dynamic> json) =>
      _$RiderBankAccountFromJson(json);

  Map<String, dynamic> toJson() => _$RiderBankAccountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
