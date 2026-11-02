// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_contacts.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SupportContactsCWProxy {
  SupportContacts phone(String phone);

  SupportContacts email(String email);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SupportContacts(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SupportContacts(...).copyWith(id: 12, name: "My name")
  /// ````
  SupportContacts call({String phone, String email});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSupportContacts.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSupportContacts.copyWith.fieldName(...)`
class _$SupportContactsCWProxyImpl implements _$SupportContactsCWProxy {
  const _$SupportContactsCWProxyImpl(this._value);

  final SupportContacts _value;

  @override
  SupportContacts phone(String phone) => this(phone: phone);

  @override
  SupportContacts email(String email) => this(email: email);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SupportContacts(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SupportContacts(...).copyWith(id: 12, name: "My name")
  /// ````
  SupportContacts call({
    Object? phone = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
  }) {
    return SupportContacts(
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
    );
  }
}

extension $SupportContactsCopyWith on SupportContacts {
  /// Returns a callable class that can be used as follows: `instanceOfSupportContacts.copyWith(...)` or like so:`instanceOfSupportContacts.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SupportContactsCWProxy get copyWith => _$SupportContactsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SupportContacts _$SupportContactsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SupportContacts', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['phone', 'email']);
      final val = SupportContacts(
        phone: $checkedConvert('phone', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$SupportContactsToJson(SupportContacts instance) =>
    <String, dynamic>{'phone': instance.phone, 'email': instance.email};
