// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_cart_update_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchedCartUpdateRequestCWProxy {
  PatchedCartUpdateRequest tip(String? tip);

  PatchedCartUpdateRequest instructions(
    DeliveryInstructionsRequest? instructions,
  );

  PatchedCartUpdateRequest addressId(int? addressId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedCartUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedCartUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedCartUpdateRequest call({
    String? tip,
    DeliveryInstructionsRequest? instructions,
    int? addressId,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchedCartUpdateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchedCartUpdateRequest.copyWith.fieldName(...)`
class _$PatchedCartUpdateRequestCWProxyImpl
    implements _$PatchedCartUpdateRequestCWProxy {
  const _$PatchedCartUpdateRequestCWProxyImpl(this._value);

  final PatchedCartUpdateRequest _value;

  @override
  PatchedCartUpdateRequest tip(String? tip) => this(tip: tip);

  @override
  PatchedCartUpdateRequest instructions(
    DeliveryInstructionsRequest? instructions,
  ) => this(instructions: instructions);

  @override
  PatchedCartUpdateRequest addressId(int? addressId) =>
      this(addressId: addressId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchedCartUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchedCartUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchedCartUpdateRequest call({
    Object? tip = const $CopyWithPlaceholder(),
    Object? instructions = const $CopyWithPlaceholder(),
    Object? addressId = const $CopyWithPlaceholder(),
  }) {
    return PatchedCartUpdateRequest(
      tip: tip == const $CopyWithPlaceholder()
          ? _value.tip
          // ignore: cast_nullable_to_non_nullable
          : tip as String?,
      instructions: instructions == const $CopyWithPlaceholder()
          ? _value.instructions
          // ignore: cast_nullable_to_non_nullable
          : instructions as DeliveryInstructionsRequest?,
      addressId: addressId == const $CopyWithPlaceholder()
          ? _value.addressId
          // ignore: cast_nullable_to_non_nullable
          : addressId as int?,
    );
  }
}

extension $PatchedCartUpdateRequestCopyWith on PatchedCartUpdateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchedCartUpdateRequest.copyWith(...)` or like so:`instanceOfPatchedCartUpdateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchedCartUpdateRequestCWProxy get copyWith =>
      _$PatchedCartUpdateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedCartUpdateRequest _$PatchedCartUpdateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchedCartUpdateRequest', json, ($checkedConvert) {
  final val = PatchedCartUpdateRequest(
    tip: $checkedConvert('tip', (v) => v as String?),
    instructions: $checkedConvert(
      'instructions',
      (v) => v == null
          ? null
          : DeliveryInstructionsRequest.fromJson(v as Map<String, dynamic>),
    ),
    addressId: $checkedConvert('address_id', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'addressId': 'address_id'});

Map<String, dynamic> _$PatchedCartUpdateRequestToJson(
  PatchedCartUpdateRequest instance,
) => <String, dynamic>{
  'tip': ?instance.tip,
  'instructions': ?instance.instructions?.toJson(),
  'address_id': ?instance.addressId,
};
