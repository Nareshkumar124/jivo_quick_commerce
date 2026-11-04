// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_bank_account.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderBankAccountCWProxy {
  RiderBankAccount holderName(String holderName);

  RiderBankAccount accountNumberMasked(String accountNumberMasked);

  RiderBankAccount ifsc(String ifsc);

  RiderBankAccount upiId(String? upiId);

  RiderBankAccount updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderBankAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderBankAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderBankAccount call({
    String holderName,
    String accountNumberMasked,
    String ifsc,
    String? upiId,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderBankAccount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderBankAccount.copyWith.fieldName(...)`
class _$RiderBankAccountCWProxyImpl implements _$RiderBankAccountCWProxy {
  const _$RiderBankAccountCWProxyImpl(this._value);

  final RiderBankAccount _value;

  @override
  RiderBankAccount holderName(String holderName) =>
      this(holderName: holderName);

  @override
  RiderBankAccount accountNumberMasked(String accountNumberMasked) =>
      this(accountNumberMasked: accountNumberMasked);

  @override
  RiderBankAccount ifsc(String ifsc) => this(ifsc: ifsc);

  @override
  RiderBankAccount upiId(String? upiId) => this(upiId: upiId);

  @override
  RiderBankAccount updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderBankAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderBankAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderBankAccount call({
    Object? holderName = const $CopyWithPlaceholder(),
    Object? accountNumberMasked = const $CopyWithPlaceholder(),
    Object? ifsc = const $CopyWithPlaceholder(),
    Object? upiId = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return RiderBankAccount(
      holderName: holderName == const $CopyWithPlaceholder()
          ? _value.holderName
          // ignore: cast_nullable_to_non_nullable
          : holderName as String,
      accountNumberMasked: accountNumberMasked == const $CopyWithPlaceholder()
          ? _value.accountNumberMasked
          // ignore: cast_nullable_to_non_nullable
          : accountNumberMasked as String,
      ifsc: ifsc == const $CopyWithPlaceholder()
          ? _value.ifsc
          // ignore: cast_nullable_to_non_nullable
          : ifsc as String,
      upiId: upiId == const $CopyWithPlaceholder()
          ? _value.upiId
          // ignore: cast_nullable_to_non_nullable
          : upiId as String?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $RiderBankAccountCopyWith on RiderBankAccount {
  /// Returns a callable class that can be used as follows: `instanceOfRiderBankAccount.copyWith(...)` or like so:`instanceOfRiderBankAccount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderBankAccountCWProxy get copyWith => _$RiderBankAccountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderBankAccount _$RiderBankAccountFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RiderBankAccount',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'holder_name',
            'account_number_masked',
            'ifsc',
            'upi_id',
            'updated_at',
          ],
        );
        final val = RiderBankAccount(
          holderName: $checkedConvert('holder_name', (v) => v as String),
          accountNumberMasked: $checkedConvert(
            'account_number_masked',
            (v) => v as String,
          ),
          ifsc: $checkedConvert('ifsc', (v) => v as String),
          upiId: $checkedConvert('upi_id', (v) => v as String?),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'holderName': 'holder_name',
        'accountNumberMasked': 'account_number_masked',
        'upiId': 'upi_id',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$RiderBankAccountToJson(RiderBankAccount instance) =>
    <String, dynamic>{
      'holder_name': instance.holderName,
      'account_number_masked': instance.accountNumberMasked,
      'ifsc': instance.ifsc,
      'upi_id': instance.upiId,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
