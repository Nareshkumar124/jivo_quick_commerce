// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_bank_account_update_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderBankAccountUpdateRequestCWProxy {
  RiderBankAccountUpdateRequest holderName(String holderName);

  RiderBankAccountUpdateRequest accountNumber(String accountNumber);

  RiderBankAccountUpdateRequest ifsc(String ifsc);

  RiderBankAccountUpdateRequest upiId(String? upiId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderBankAccountUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderBankAccountUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderBankAccountUpdateRequest call({
    String holderName,
    String accountNumber,
    String ifsc,
    String? upiId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderBankAccountUpdateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderBankAccountUpdateRequest.copyWith.fieldName(...)`
class _$RiderBankAccountUpdateRequestCWProxyImpl
    implements _$RiderBankAccountUpdateRequestCWProxy {
  const _$RiderBankAccountUpdateRequestCWProxyImpl(this._value);

  final RiderBankAccountUpdateRequest _value;

  @override
  RiderBankAccountUpdateRequest holderName(String holderName) =>
      this(holderName: holderName);

  @override
  RiderBankAccountUpdateRequest accountNumber(String accountNumber) =>
      this(accountNumber: accountNumber);

  @override
  RiderBankAccountUpdateRequest ifsc(String ifsc) => this(ifsc: ifsc);

  @override
  RiderBankAccountUpdateRequest upiId(String? upiId) => this(upiId: upiId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderBankAccountUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderBankAccountUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderBankAccountUpdateRequest call({
    Object? holderName = const $CopyWithPlaceholder(),
    Object? accountNumber = const $CopyWithPlaceholder(),
    Object? ifsc = const $CopyWithPlaceholder(),
    Object? upiId = const $CopyWithPlaceholder(),
  }) {
    return RiderBankAccountUpdateRequest(
      holderName: holderName == const $CopyWithPlaceholder()
          ? _value.holderName
          // ignore: cast_nullable_to_non_nullable
          : holderName as String,
      accountNumber: accountNumber == const $CopyWithPlaceholder()
          ? _value.accountNumber
          // ignore: cast_nullable_to_non_nullable
          : accountNumber as String,
      ifsc: ifsc == const $CopyWithPlaceholder()
          ? _value.ifsc
          // ignore: cast_nullable_to_non_nullable
          : ifsc as String,
      upiId: upiId == const $CopyWithPlaceholder()
          ? _value.upiId
          // ignore: cast_nullable_to_non_nullable
          : upiId as String?,
    );
  }
}

extension $RiderBankAccountUpdateRequestCopyWith
    on RiderBankAccountUpdateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRiderBankAccountUpdateRequest.copyWith(...)` or like so:`instanceOfRiderBankAccountUpdateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderBankAccountUpdateRequestCWProxy get copyWith =>
      _$RiderBankAccountUpdateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderBankAccountUpdateRequest _$RiderBankAccountUpdateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RiderBankAccountUpdateRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['holder_name', 'account_number', 'ifsc'],
    );
    final val = RiderBankAccountUpdateRequest(
      holderName: $checkedConvert('holder_name', (v) => v as String),
      accountNumber: $checkedConvert('account_number', (v) => v as String),
      ifsc: $checkedConvert('ifsc', (v) => v as String),
      upiId: $checkedConvert('upi_id', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'holderName': 'holder_name',
    'accountNumber': 'account_number',
    'upiId': 'upi_id',
  },
);

Map<String, dynamic> _$RiderBankAccountUpdateRequestToJson(
  RiderBankAccountUpdateRequest instance,
) => <String, dynamic>{
  'holder_name': instance.holderName,
  'account_number': instance.accountNumber,
  'ifsc': instance.ifsc,
  'upi_id': ?instance.upiId,
};
