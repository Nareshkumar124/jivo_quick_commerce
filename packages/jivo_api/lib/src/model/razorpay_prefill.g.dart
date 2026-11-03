// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'razorpay_prefill.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RazorpayPrefillCWProxy {
  RazorpayPrefill name(String name);

  RazorpayPrefill contact(String contact);

  RazorpayPrefill email(String email);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayPrefill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayPrefill(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayPrefill call({String name, String contact, String email});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRazorpayPrefill.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRazorpayPrefill.copyWith.fieldName(...)`
class _$RazorpayPrefillCWProxyImpl implements _$RazorpayPrefillCWProxy {
  const _$RazorpayPrefillCWProxyImpl(this._value);

  final RazorpayPrefill _value;

  @override
  RazorpayPrefill name(String name) => this(name: name);

  @override
  RazorpayPrefill contact(String contact) => this(contact: contact);

  @override
  RazorpayPrefill email(String email) => this(email: email);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RazorpayPrefill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RazorpayPrefill(...).copyWith(id: 12, name: "My name")
  /// ````
  RazorpayPrefill call({
    Object? name = const $CopyWithPlaceholder(),
    Object? contact = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
  }) {
    return RazorpayPrefill(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      contact: contact == const $CopyWithPlaceholder()
          ? _value.contact
          // ignore: cast_nullable_to_non_nullable
          : contact as String,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String,
    );
  }
}

extension $RazorpayPrefillCopyWith on RazorpayPrefill {
  /// Returns a callable class that can be used as follows: `instanceOfRazorpayPrefill.copyWith(...)` or like so:`instanceOfRazorpayPrefill.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RazorpayPrefillCWProxy get copyWith => _$RazorpayPrefillCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RazorpayPrefill _$RazorpayPrefillFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RazorpayPrefill', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'contact', 'email']);
      final val = RazorpayPrefill(
        name: $checkedConvert('name', (v) => v as String),
        contact: $checkedConvert('contact', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$RazorpayPrefillToJson(RazorpayPrefill instance) =>
    <String, dynamic>{
      'name': instance.name,
      'contact': instance.contact,
      'email': instance.email,
    };
